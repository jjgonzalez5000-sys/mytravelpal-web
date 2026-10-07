"""Compose a natural-language narrative for a planned trip.

The service formats the trip plan into a compact structured prompt that
Claude can turn into a friendly text description with additional
recommendations. Everything a Premium user sees is derived from data
the free planner already produces — this feature adds a *layer of
interpretation*, not new external data sources.
"""

from __future__ import annotations

from datetime import datetime

from app.domain import (
    AdverseEvent,
    Coordinate,
    Country,
    Hotel,
    Restaurant,
    RestStop,
    Route,
    TimeWindow,
)
from app.providers.llm import LlmProvider


_SYSTEM_INTRO = (
    "You are MyTravelPal's road-trip concierge. You describe a planned drive "
    "in a friendly, concise way — 3 to 5 short paragraphs — then add 3 to 5 "
    "practical recommendations tailored to the specific trip. You focus on "
    "what the driver actually needs to know: when to leave, what's already "
    "planned, what to watch out for, what's worth stopping for.\n\n"
    "IMPORTANT: The trip data below includes a section called "
    "'Planned meal stops', 'Planned overnight stop', and 'Multi-day plan'. "
    "These are the ACTUAL stops the app has already scheduled for this trip. "
    "Your narrative must reflect this plan accurately — never suggest stops "
    "that are already covered, never say 'consider stopping' for something "
    "that's already in the itinerary. If the plan has 5 meal stops, say so "
    "and describe them specifically.\n\n"
    "Do NOT invent facts. Only use the structured trip data provided. If a "
    "section is missing, don't mention it. Keep the tone helpful, direct, "
    "and free of marketing fluff. Never suggest anything that would compromise "
    "road safety. Avoid markdown formatting (no asterisks, no #, no bullet "
    "symbols like * or -) — write in clean prose and numbered recommendations."
)


def build_prompt(
    *,
    origin_name: str,
    destination_name: str,
    desired_departure_at: datetime,
    route: Route,
    recommended: TimeWindow | None,
    rest_stops: tuple[RestStop, ...],
    hotels: tuple[Hotel, ...],
    restaurants: tuple[Restaurant, ...],
    adverse_events: tuple[AdverseEvent, ...],
    planned_meal_stops: list[dict] | None = None,
    planned_sleep: dict | None = None,
    planned_days: list[dict] | None = None,
    language_directive: str = "",
) -> str:
    """Render the structured prompt sent to the LLM.

    Deterministic pure function — trivially unit-testable, and keeps
    prompt engineering out of the provider so we can tune it without
    touching the API-integration code.

    `language_directive` is inserted directly under the system intro
    so Claude sees the language requirement before any factual data.
    Empty string (the default) keeps the historical English output
    for older callers that don't pass a locale.
    """
    lines: list[str] = [_SYSTEM_INTRO]
    if language_directive:
        lines.extend(["", language_directive])
    lines.extend(["", "Trip:"])
    lines.append(f"- From: {origin_name}")
    lines.append(f"- To: {destination_name}")
    lines.append(f"- Desired departure: {desired_departure_at.isoformat()}")
    lines.append(
        f"- Route: {route.distance_km:.0f} km, "
        f"~{route.free_flow_duration.total_seconds() / 3600.0:.1f} h free flow, "
        f"tolls ~{route.toll_cost_eur:.0f} EUR",
    )
    if route.countries_crossed:
        lines.append(
            "- Countries crossed: "
            + ", ".join(_country_name(c) for c in route.countries_crossed),
        )

    if recommended is not None:
        lines.append("")
        lines.append("Best departure window:")
        shift_minutes = int((recommended.departure_at - desired_departure_at).total_seconds() // 60)
        lines.append(
            f"- Leave at {recommended.departure_at.isoformat()} "
            f"(traffic factor x{recommended.traffic_factor:.2f}, "
            f"~{recommended.estimated_duration.total_seconds() / 60:.0f} min total; "
            f"shift {shift_minutes:+d} min vs desired).",
        )

    # ── ACTUAL PLANNED ITINERARY (highest priority context for the LLM) ──
    # These are the SPECIFIC stops the app has already placed — the LLM
    # must base the narrative on this plan, not invent new stops.
    if planned_days:
        lines.append("")
        if len(planned_days) == 1:
            d = planned_days[0]
            lines.append(
                f"This is a single-day trip: {d['km']:.0f} km in one drive."
            )
        else:
            lines.append(f"Multi-day plan ({len(planned_days)} days):")
            for d in planned_days:
                sleep = f", sleep ~{d['sleep_at'][:10]}" if d.get("sleep_at") else ""
                lines.append(
                    f"- Day {d['day']}: {d['km']:.0f} km "
                    f"(km {d['from_km']:.0f}–{d['to_km']:.0f}){sleep}."
                )

    if planned_meal_stops:
        lines.append("")
        lines.append(f"Planned meal stops ({len(planned_meal_stops)} total):")
        for m in planned_meal_stops:
            rest_name = m.get("restaurant") or "unnamed stop"
            city = f" near {m['city']}" if m.get("city") else ""
            price = f", ~{m['price_eur']:.0f} EUR/meal" if m.get("price_eur") else ""
            lines.append(
                f"- {m['slot'].capitalize()} at {m['at'][11:16]}{city}: "
                f"{rest_name}{price} (km {m['km']:.0f})."
            )

    if planned_sleep:
        lines.append("")
        hotel = planned_sleep.get("hotel") or "unnamed hotel"
        city = f" in {planned_sleep['city']}" if planned_sleep.get("city") else ""
        price = f", ~{planned_sleep['price_eur']:.0f} EUR/night" if planned_sleep.get("price_eur") else ""
        lines.append(
            f"Planned overnight stop{city}: {hotel}{price} "
            f"(km {planned_sleep['km']:.0f}, sleep at {planned_sleep['at'][11:16]})."
        )
    # ─────────────────────────────────────────────────────────────────────

    if rest_stops:
        lines.append("")
        lines.append("Available rest areas along the route:")
        for s in rest_stops[:4]:
            lines.append(
                f"- After {s.cumulative_driving_hours:.1f} h "
                f"({s.distance_from_origin_km:.0f} km from origin), "
                f"suggested break {s.recommended_break_minutes} min.",
            )

    if hotels and not planned_sleep:
        lines.append("")
        lines.append("Hotels considered along the route:")
        for h in hotels[:3]:
            lines.append(
                f"- {h.name} ({_country_name(h.country)}), "
                f"{h.price_eur_per_night:.0f} EUR/night, "
                f"+{h.detour_minutes:.0f} min detour.",
            )

    if restaurants and not planned_meal_stops:
        lines.append("")
        lines.append("Restaurants considered along the route:")
        for r in restaurants[:3]:
            lines.append(
                f"- {r.name} ({_country_name(r.country)}), "
                f"{r.price_eur_per_meal:.0f} EUR/meal, "
                f"+{r.detour_minutes:.0f} min detour.",
            )

    if adverse_events:
        lines.append("")
        lines.append("Known adverse events on or near the route:")
        for e in adverse_events[:8]:
            lines.append(
                f"- [{e.severity.value.upper()}] {e.type.value}: {e.description} "
                f"(source: {e.source.value}).",
            )

    lines.append("")
    lines.append(
        "Write the narrative now: 3–4 short paragraphs describing the drive "
        "as if you were briefing a friend. Refer to the specific planned stops "
        "by name and time. Then write a numbered list titled 'Recomendaciones' "
        "(or 'Recommendations' if language is English) with 3–5 practical, "
        "trip-specific tips — only tips that are NOT already covered by the "
        "planned itinerary. Use plain prose, no markdown symbols.",
    )
    return "\n".join(lines)


async def generate_trip_narrative(
    *,
    llm: LlmProvider,
    origin_name: str,
    destination_name: str,
    desired_departure_at: datetime,
    route: Route,
    recommended: TimeWindow | None,
    rest_stops: tuple[RestStop, ...],
    hotels: tuple[Hotel, ...],
    restaurants: tuple[Restaurant, ...],
    adverse_events: tuple[AdverseEvent, ...],
    planned_meal_stops: list[dict] | None = None,
    planned_sleep: dict | None = None,
    planned_days: list[dict] | None = None,
    language_directive: str = "",
) -> str:
    prompt = build_prompt(
        origin_name=origin_name,
        destination_name=destination_name,
        desired_departure_at=desired_departure_at,
        route=route,
        recommended=recommended,
        rest_stops=rest_stops,
        hotels=hotels,
        restaurants=restaurants,
        adverse_events=adverse_events,
        planned_meal_stops=planned_meal_stops,
        planned_sleep=planned_sleep,
        planned_days=planned_days,
        language_directive=language_directive,
    )
    return await llm.generate_narrative(prompt)


_COUNTRY_NAMES = {
    Country.CH: "Switzerland",
    Country.FR: "France",
    Country.IT: "Italy",
    Country.ES: "Spain",
}


def _country_name(c: Country) -> str:
    return _COUNTRY_NAMES.get(c, c.value)
