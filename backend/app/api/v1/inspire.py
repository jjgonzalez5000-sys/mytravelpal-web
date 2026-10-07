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

from fastapi import APIRouter, Depends, Header, HTTPException, Query, status
from pydantic import BaseModel, Field

from app.api.ai_quota import require_inspire_quota
from app.auth.jwt import AuthUser
from app.providers import get_providers
from app.providers.factory import Providers


# Mapping used by every LLM endpoint to force the model to answer in
# the driver's language. Kept explicit (not just BCP-47 codes) because
# Claude follows named-language directives noticeably more reliably
# than 2-letter codes buried in prose.
_LANGUAGE_NAMES: dict[str, str] = {
    "en": "English",
    "es": "Spanish",
    "fr": "French",
    "de": "German",
    "it": "Italian",
    "ca": "Catalan",
    "pt": "Portuguese",
}


def _language_instruction(lang: str | None) -> str:
    """Return a strong, top-of-prompt directive telling the LLM which
    language to use for every user-facing string in its JSON output.

    Empty when `lang` is null/blank/unsupported — the caller then
    inherits the historical English default so old clients keep
    working unchanged.
    """
    if not lang:
        return ""
    code = lang.strip().lower().split("-")[0]
    name = _LANGUAGE_NAMES.get(code)
    if name is None:
        return ""
    return (
        f"IMPORTANT: Write ALL user-facing text (summary, highlights, "
        f"note, from_name, to_name, hotel_area, assistant_note) in "
        f"{name}. Never mix languages. Place names may stay in their "
        f"native form when there is no common {name} exonym."
    )


def _resolve_locale(
    body_locale: str | None,
    query_lang: str | None,
    accept_language: str | None,
) -> str | None:
    """Pick a locale from the three redundant channels the client can
    use. Body field wins (explicit intent), then the ?lang= query
    param, then the Accept-Language header. Returns the raw 2-letter
    code (lowercased) or None when nothing usable came through.
    """
    for candidate in (body_locale, query_lang, accept_language):
        if not candidate:
            continue
        # Accept-Language may look like "es-ES,es;q=0.9,en;q=0.8" —
        # take the first token before either comma or semicolon.
        primary = candidate.split(",")[0].split(";")[0].strip()
        if not primary:
            continue
        code = primary.lower().split("-")[0]
        if len(code) == 2 and code.isalpha():
            return code
    return None

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
    today_iso: str | None = Field(
        default=None,
        pattern=r"^\d{4}-\d{2}-\d{2}$",
        description=(
            "Client-local `YYYY-MM-DD`. When present it wins over "
            "the server-side UTC date for the LLM's 'today' anchor. "
            "Fixes weekday off-by-one bugs when the user's local "
            "date differs from UTC (late night / early morning)."
        ),
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
    # Timing hints inferred from the user prompt. `_iso` is the
    # authoritative field; `_days_from_now` is kept for backward
    # compat with older mobile builds. The client should prefer
    # `_iso` when both are present.
    suggested_departure_iso: str | None = None
    suggested_departure_days_from_now: int | None = None
    suggested_departure_hour: int | None = None
    # Short assistant reply (1-2 sentences) explaining what the
    # LLM did — set by `/refine` only. `/inspire` leaves it null
    # since the whole payload IS the response.
    assistant_note: str | None = None


class InspireChatTurn(BaseModel):
    """One message in the refinement conversation."""
    role: str  # "user" | "assistant"
    content: str


class InspireRefineRequest(BaseModel):
    prompt: str = Field(
        ..., min_length=1, max_length=500,
        description=(
            "User's refinement request, e.g. 'quita el día en Cremona' "
            "or 'salir viernes por la tarde en vez de mañana'."
        ),
    )
    previous_itinerary: InspireResponse = Field(
        ...,
        description=(
            "The itinerary the LLM last emitted. The refine call "
            "modifies THIS, not a fresh generation."
        ),
    )
    history: list[InspireChatTurn] = Field(
        default_factory=list, max_length=20,
        description=(
            "Prior turns of the conversation (oldest first). Capped "
            "at 20 messages so the context stays cheap."
        ),
    )
    locale: str = Field(
        default="en",
        pattern=r"^[a-zA-Z]{2}(-[A-Za-z]{2})?$",
    )
    today_iso: str | None = Field(
        default=None,
        pattern=r"^\d{4}-\d{2}-\d{2}$",
    )


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
  "suggested_departure_iso": "2026-09-04",
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
- `suggested_departure_iso`: parse the prompt for a departure
  hint and emit a concrete ISO date `YYYY-MM-DD`. RETURN AN ISO
  DATE, NOT AN OFFSET — offsets have been unreliable historically.
  Reasoning template:
    1. Anchor `Today` (a specific date + weekday). Use that as
       ground truth for weekday arithmetic.
    2. Compute the target date from the prompt:
       * "salgo el viernes" / "on Friday" / "vendredi" -> the NEXT
         occurrence of Friday on or after Today. If Today IS
         Friday, return today's date.
       * "weekend" / "fin de semana" -> next Friday on or after Today
       * "next weekend" / "próximo finde" -> the Friday of the
         calendar week AFTER Today's week
       * "tomorrow" -> Today + 1 calendar day
       * "next week" -> Today + 7 calendar days
       * Explicit "October 5th" -> that date in the current year
         (or next year if it's already in the past)
       * When no time hint at all, OMIT the field.
    3. Sanity-check: the target must be ≤ 60 days from Today.
- `suggested_departure_hour`: 8 for morning starts, 14 for
  post-lunch, 18 for evening. Omit when no hint.
- Today's date is passed in the user prompt as `Today:` (with
  the exact weekday spelled out). Use it verbatim.
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
    # Redundant locale channels: body field wins, ?lang=xx and
    # Accept-Language act as fallbacks so a client that only sets
    # the standard HTTP header still gets a translated response.
    lang: str | None = Query(default=None, max_length=16),
    accept_language: str | None = Header(default=None, alias="Accept-Language"),
) -> InspireResponse:
    """Generate a proposed itinerary from a free-form prompt."""
    origin_line = (
        f"Origin GPS: {payload.origin.lat:.4f},{payload.origin.lon:.4f}\n"
        if payload.origin else ""
    )
    # Prefer client's local date over server-side UTC to avoid
    # weekday-off-by-one bugs when the driver plans late at night.
    from datetime import date as _date
    if payload.today_iso:
        try:
            today = _date.fromisoformat(payload.today_iso)
        except ValueError:
            today = datetime.now(timezone.utc).date()
    else:
        today = datetime.now(timezone.utc).date()
    weekday_names = [
        "Monday", "Tuesday", "Wednesday", "Thursday",
        "Friday", "Saturday", "Sunday",
    ]
    today_line = (
        f"Today: {today.isoformat()} ({weekday_names[today.weekday()]})\n"
    )
    # Body field defaults to "en", so treat that as "no explicit
    # request" and let the header/query fallbacks contribute.
    body_locale = payload.locale if payload.locale != "en" else None
    resolved_lang = (
        _resolve_locale(body_locale, lang, accept_language)
        or payload.locale
    )
    language_line = _language_instruction(resolved_lang)
    language_block = f"{language_line}\n\n" if language_line else ""
    user_prompt = (
        f"{_SYSTEM_PROMPT}\n\n"
        f"{language_block}"
        f"{today_line}"
        f"Locale: {resolved_lang}\n"
        f"{origin_line}"
        f"Prompt: {payload.prompt}"
    )
    try:
        raw = await providers.llm.generate_narrative(user_prompt, user_id=user.id, endpoint="inspire")
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
        response = InspireResponse.model_validate(parsed)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail={
                "error": "llm_bad_schema",
                "message": str(exc),
                "raw": raw[:400],
            },
        ) from exc
    # Bridge iso ↔ offset: whichever field the LLM emitted, we
    # populate both so mobile builds on either side work. If the
    # ISO is in the past OR farther than 60 days, drop it — the
    # LLM hallucinated a date and mobile shouldn't be poisoned.
    if response.suggested_departure_iso:
        try:
            iso = _date.fromisoformat(response.suggested_departure_iso)
            delta = (iso - today).days
            if 0 <= delta <= 60:
                response = response.model_copy(
                    update={"suggested_departure_days_from_now": delta},
                )
            else:
                _log.warning(
                    "LLM emitted out-of-range departure ISO %s (delta=%d)",
                    response.suggested_departure_iso, delta,
                )
                response = response.model_copy(update={
                    "suggested_departure_iso": None,
                    "suggested_departure_days_from_now": None,
                })
        except ValueError:
            response = response.model_copy(update={
                "suggested_departure_iso": None,
            })
    elif response.suggested_departure_days_from_now is not None:
        # Backfill ISO from the offset the LLM did emit so mobile
        # can always prefer ISO uniformly.
        offset = response.suggested_departure_days_from_now
        if 0 <= offset <= 60:
            from datetime import timedelta as _td
            response = response.model_copy(update={
                "suggested_departure_iso":
                    (today + _td(days=offset)).isoformat(),
            })
    return response


_REFINE_SYSTEM_PROMPT = """\
You are refining an existing MyTravelPal itinerary. The user is
in an ongoing conversation with you and wants to tweak, not
regenerate from scratch.

You will receive:
- The previous itinerary as JSON
- The user's new request in natural language

Return a JSON object with:
- `assistant_note`: 1-2 short sentences (in the requested locale)
  explaining what you changed and why. Speak in first person like
  a friend planning together: "Vale, quitamos Cremona y ganamos
  media tarde en Módena. He movido el hotel a…". Never say "I
  updated the itinerary as requested" — be specific and useful.
- ALL other fields of the original schema (summary, days,
  waypoints, hotel_area, highlights, total_distance_km_estimate,
  estimated_budget_eur, suggested_departure_iso,
  suggested_departure_hour). Keep values UNCHANGED unless the
  user's request implies changing them.

Rules:
- Preserve REAL coordinates. Reuse existing waypoint coords when
  the user's edit doesn't touch them. Only invent new coords for
  waypoints the user asked to add.
- If the user asks something impossible or unclear, still return
  the previous itinerary unchanged, and use `assistant_note` to
  ask a follow-up question. Never crash the conversation.
- Locale + today anchor come in the prompt below the schema.
"""


@router.post("/inspire/refine", response_model=InspireResponse)
async def inspire_refine(
    payload: InspireRefineRequest,
    providers: Providers = Depends(get_providers),
    user: AuthUser = Depends(require_inspire_quota),
    lang: str | None = Query(default=None, max_length=16),
    accept_language: str | None = Header(default=None, alias="Accept-Language"),
) -> InspireResponse:
    """Turn-by-turn refinement of an existing itinerary."""
    from datetime import date as _date
    if payload.today_iso:
        try:
            today = _date.fromisoformat(payload.today_iso)
        except ValueError:
            today = datetime.now(timezone.utc).date()
    else:
        today = datetime.now(timezone.utc).date()
    weekday_names = [
        "Monday", "Tuesday", "Wednesday", "Thursday",
        "Friday", "Saturday", "Sunday",
    ]
    today_line = (
        f"Today: {today.isoformat()} ({weekday_names[today.weekday()]})\n"
    )
    # Serialise the previous itinerary compactly so the LLM sees a
    # complete but small context. Drops null fields to save tokens.
    prev = payload.previous_itinerary.model_dump(
        exclude_none=True, exclude={"assistant_note"},
    )
    history_block = ""
    if payload.history:
        turns = []
        for m in payload.history[-10:]:
            role = "User" if m.role == "user" else "Assistant"
            turns.append(f"{role}: {m.content}")
        history_block = "Conversation so far:\n" + "\n".join(turns) + "\n\n"
    body_locale = payload.locale if payload.locale != "en" else None
    resolved_lang = (
        _resolve_locale(body_locale, lang, accept_language)
        or payload.locale
    )
    language_line = _language_instruction(resolved_lang)
    language_block = f"{language_line}\n\n" if language_line else ""
    user_prompt = (
        f"{_REFINE_SYSTEM_PROMPT}\n\n"
        f"{language_block}"
        f"{today_line}"
        f"Locale: {resolved_lang}\n\n"
        f"Previous itinerary:\n{json.dumps(prev, ensure_ascii=False)}\n\n"
        f"{history_block}"
        f"New user request: {payload.prompt}\n\n"
        f"Return the FULL updated itinerary as JSON with an "
        f"`assistant_note` field on the top level."
    )
    try:
        raw = await providers.llm.generate_narrative(user_prompt, user_id=user.id, endpoint="inspire")
    except Exception as exc:  # noqa: BLE001
        _log.warning("LLM refine failed: %r", exc)
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
                "message": "LLM refine returned unparseable output.",
                "raw": raw[:400],
            },
        )
    try:
        response = InspireResponse.model_validate(parsed)
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail={
                "error": "llm_bad_schema",
                "message": str(exc),
                "raw": raw[:400],
            },
        ) from exc
    # Same iso ↔ offset bridge as /inspire, and same 60-day guard.
    if response.suggested_departure_iso:
        try:
            iso = _date.fromisoformat(response.suggested_departure_iso)
            delta = (iso - today).days
            if 0 <= delta <= 60:
                response = response.model_copy(
                    update={"suggested_departure_days_from_now": delta},
                )
            else:
                response = response.model_copy(update={
                    "suggested_departure_iso": None,
                    "suggested_departure_days_from_now": None,
                })
        except ValueError:
            response = response.model_copy(update={
                "suggested_departure_iso": None,
            })
    return response


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
