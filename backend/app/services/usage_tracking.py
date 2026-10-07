"""Fire-and-forget logger for costly external API calls.

Writes to the `usage_events` table so the admin dashboard can
show €/day per provider + who is burning the budget. Silently
no-ops when the DB isn't reachable — telemetry must NEVER break
the primary request path.

Cost estimates are per-provider and stored in EUR at call time
so historical rows survive future price changes. Update the
constants below when a provider's rate card shifts.
"""

from __future__ import annotations

import json
import logging
from typing import Any

from sqlalchemy import text

from app.db import get_session, is_available as db_available

_log = logging.getLogger(__name__)

# Rough per-1k-token cost estimates (EUR). Convert USD → EUR at
# 0.92 to keep the dashboard in a single currency. Update as
# providers change rates.
COST_LLM_INPUT_PER_1K_TOKENS_EUR = 0.0028   # Claude Haiku 4.5 input
COST_LLM_OUTPUT_PER_1K_TOKENS_EUR = 0.014   # Claude Haiku 4.5 output
COST_HERE_PLACES_CALL_EUR = 0.00050         # $0.55 per 1000 calls
COST_HERE_ROUTING_CALL_EUR = 0.00046        # $0.50 per 1000 calls
COST_GEOAPIFY_CALL_EUR = 0.00046            # Free tier -> 0 in practice
COST_TOLLGURU_CALL_EUR = 0.00092            # ~$1 per 1000 calls
COST_NEGLIGIBLE_EUR = 0.0                   # Free / self-hosted (OSRM, Nominatim)


async def log_event(
    *,
    user_id: str | None,
    provider: str,
    endpoint: str,
    cost_eur: float,
    tokens_in: int | None = None,
    tokens_out: int | None = None,
    meta: dict[str, Any] | None = None,
) -> None:
    """Insert one row into `usage_events`. Errors are swallowed."""
    if not db_available():
        return
    try:
        async with get_session() as session:
            await session.execute(
                text(
                    """
                    INSERT INTO usage_events (
                        user_id, provider, endpoint, tokens_in, tokens_out,
                        cost_eur, meta
                    )
                    VALUES (
                        :user_id, :provider, :endpoint, :tokens_in, :tokens_out,
                        :cost_eur, CAST(:meta AS JSONB)
                    )
                    """
                ),
                {
                    "user_id": user_id,
                    "provider": provider,
                    "endpoint": endpoint,
                    "tokens_in": tokens_in,
                    "tokens_out": tokens_out,
                    "cost_eur": float(cost_eur),
                    "meta": json.dumps(meta) if meta else None,
                },
            )
            await session.commit()
    except Exception as exc:  # noqa: BLE001
        _log.warning("usage_events insert failed: %r", exc)


def estimate_llm_cost_eur(tokens_in: int, tokens_out: int) -> float:
    """Convert token counts to EUR using the constants above."""
    return round(
        (tokens_in / 1000.0) * COST_LLM_INPUT_PER_1K_TOKENS_EUR
        + (tokens_out / 1000.0) * COST_LLM_OUTPUT_PER_1K_TOKENS_EUR,
        6,
    )
