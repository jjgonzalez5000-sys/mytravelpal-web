"""Trip Inspiration — LLM-generated multi-day itineraries.

The killer marketing feature per `project_launch_plan`. User
types a free-form prompt like "romantic 4-day road trip through
Italy" or "castles of the Loire in a weekend" and Claude Haiku
returns a structured itinerary the mobile app can render as a
timeline and one-tap convert into a real multi-stop plan the
existing `/v1/trips/plan` pipeline handles.

Cost per generation: ~$0.012 (2k in + 2k out on Haiku 4.5). Free
tier gates enforced client-side via SharedPreferences counter;
Premium unlocks unlimited.

Design choices:
- Text-in / JSON-out. We ask Haiku for a strict JSON schema in
  the system prompt and parse; a re-ask on parse failure is
  cheaper than fighting with structured-output beta features
  and works well with Haiku's high JSON-fidelity.
- No caching (each prompt is unique enough that TTL cache would
  rarely hit).
- Locale-aware. Client passes `locale` so the LLM writes the
  narrative + POI descriptions in the driver's language.
"""

from __future__ import annotations

import json
import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from app.api.ai_quota import require_inspire_quota
from app.auth.jwt import AuthUser
from app.providers import get_providers
from app.providers.factory import Providers

router = APIRouter(prefix="/trips", tags=["inspire"])
_log = logging.getLogger(__name__)


class LatLonIn(BaseModel):
    lat: float
    lon: float


class InspireRequest(BaseModel):
    """User-facing input for a trip-inspiration call."""

    prompt: str = Field(
        ..., min_length=8, max_length=500,
        description="Free-form describing the trip vibe, region, days, style.",
    )
    origin: LatLonIn | None = Field(
        default=None,
        description=(
            "Optional starting point. When provided the LLM anchors "
            "the itinerary to it; when omitted the LLM picks a "
            "sensible city from the prompt."
        ),
    )
    locale: str = Field(
        default="en",
        pattern=r"^[a-zA-Z]{2}(-[A-Za-z]{2})?$",
        description="BCP-47 code — LLM outputs narrative in this locale.",
    )


class InspirePoi(BaseModel):
    """One point-of-interest in the itinerary."""
    name: str
    lat: float
    lon: float
    # Category slug: `city`, `landmark`, `viewpoint`, `museum`,
    # `nature`, `beach`, `village`, `hotel`, `restaurant`, `other`.
    kind: str
    # 1-2 sentence local-language justification for why this stop.
    note: str


class InspireDay(BaseModel):
    day: int
    from_name: str
    to_name: str
    distance_km_estimate: float | None = None
    driving_hours_estimate: float | None = None
    waypoints: list[InspirePoi] = Field(default_factory=list)
    hotel_area: str | None = None
    highlights: str = Field(default="")


class InspireResponse(BaseModel):
    summary: str
    days: list[InspireDay]
    total_distance_km_estimate: float | None = None
    estimated_budget_eur: float | None = None
    # Timing hints inferred from the user prompt. When the driver
    # says "weekend" / "next Friday" / "in two weeks", the LLM
    # returns concrete offsets we can turn into a real departure
    # datetime on the client instead of defaulting to "tomorrow
    # 08:00" which almost never matches the intent.
    suggested_departure_days_from_now: int | None = None
    suggested_departure_hour: int | None = None


_SYSTEM_PROMPT = """\
You are MyTravelPal's trip-inspiration assistant. Given a
free-form prompt from a road-tripper, propose a multi-day driving
itinerary in Europe. Output ONLY a JSON object matching this
schema (no prose, no code fences):

{
  "summary": "1-2 sentence pitch for the whole trip",
  "days": [
    {
      "day": 1,
      "from_name": "City",
      "to_name": "City",
      "distance_km_estimate": 250.0,
      "driving_hours_estimate": 3.5,
      "waypoints": [
        {
          "name": "Real place name",
          "lat": 46.12,
          "lon": 9.83,
          "kind": "landmark|viewpoint|museum|nature|beach|village|city|other",
          "note": "1-2 sentences on why to stop"
        }
      ],
      "hotel_area": "City or district for the overnight",
      "highlights": "Short paragraph on what makes today special"
    }
  ],
  "total_distance_km_estimate": 850.0,
  "estimated_budget_eur": 480.0,
  "suggested_departure_days_from_now": 4,
  "suggested_departure_hour": 8
}

Rules:
- Use REAL places with accurate coordinates. If you're not sure
  of coordinates, pick nearby well-known ones you're confident
  about.
- Keep daily driving under 5 hours unless the prompt asks
  explicitly for a marathon leg.
- Include 2-4 waypoints per day beyond the endpoints — real POIs
  the driver would stop at.
- Match the prompt's requested duration; when unspecified,
  propose 3-5 days.
- Write `summary`, `note`, `highlights` in the requested locale.
- `estimated_budget_eur` covers fuel + tolls + food + mid-range
  hotels for the whole party.
- `suggested_departure_days_from_now`: parse the prompt for time
  hints and emit a concrete integer:
    * "weekend" / "fin de semana" -> next Friday from today (compute
      how many days from today's weekday to Friday; if today is
      already Friday, return 0)
    * "next weekend" / "próximo finde" -> Friday after the coming one
    * "tomorrow" -> 1
    * "next week" -> 7
    * "in two weeks" -> 14
    * Explicit date (e.g. "on October 5th") -> days from today to
      that date
    * When no time hint at all, OMIT the field.
- `suggested_departure_hour`: 8 for morning starts, 14 for
  post-lunch, 18 for evening. Omit when no hint.
- Today's date is passed in the user prompt as `Today:` so you
  can compute the offset correctly.
"""


@router.post("/inspire", response_model=InspireResponse)
async def inspire(
    payload: InspireRequest,
    providers: Providers = Depends(get_providers),
    # JWT + daily quota gate (see project_ai_cost_defense memory).
    # Anonymous callers get 401; users past their cap get 429 with
    # the reset time embedded in the payload so the mobile UI can
    # show a helpful message rather than a raw error.
    user: AuthUser = Depends(require_inspire_quota),
) -> InspireResponse:
    """Generate a proposed itinerary from a free-form prompt."""
    origin_line = (
        f"Origin GPS: {payload.origin.lat:.4f},{payload.origin.lon:.4f}\n"
        if payload.origin else ""
    )
    today = datetime.now(timezone.utc).date()
    weekday_names = [
        "Monday", "Tuesday", "Wednesday", "Thursday",
        "Friday", "Saturday", "Sunday",
    ]
    today_line = (
        f"Today: {today.isoformat()} ({weekday_names[today.weekday()]})\n"
    )
    user_prompt = (
        f"{_SYSTEM_PROMPT}\n\n"
        f"{today_line}"
        f"Locale: {payload.locale}\n"
        f"{origin_line}"
        f"Prompt: {payload.prompt}"
    )
    try:
        raw = await providers.llm.generate_narrative(user_prompt)
    except Exception as exc:  # noqa: BLE001
        _log.warning("LLM inspiration failed: %r", exc)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail={"error": "llm_unavailable", "message": str(exc)},
        ) from exc
    parsed = _parse_json(raw)
    if parsed is None:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail={
                "error": "llm_bad_json",
                "message": "LLM returned unparseable output.",
                "raw": raw[:400],
            },
        )
    try:
        return InspireResponse.model_validate(parsed)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail={
                "error": "llm_bad_schema",
                "message": str(exc),
                "raw": raw[:400],
            },
        ) from exc


def _parse_json(text: str) -> dict | None:
    """Extract the JSON object from the LLM response. Handles the
    two common failure modes: the LLM wraps the JSON in ``` code
    fences, or prepends a short natural-language intro. We look
    for the first `{` and the matching last `}` and try to load
    that slice.
    """
    text = text.strip()
    # Strip common markdown code fence.
    if text.startswith("```"):
        # Drop first line + trailing fence.
        lines = text.splitlines()
        if lines and lines[0].startswith("```"):
            lines = lines[1:]
        if lines and lines[-1].startswith("```"):
            lines = lines[:-1]
        text = "\n".join(lines).strip()
    # Bracket slice as fallback.
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass
    start = text.find("{")
    end = text.rfind("}")
    if start == -1 or end == -1 or end <= start:
        return None
    try:
        return json.loads(text[start:end + 1])
    except json.JSONDecodeError:
        return None
