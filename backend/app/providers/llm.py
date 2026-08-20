"""Language-model providers for the AI trip assistant.

The default LLM is **Claude Opus 5** (`claude-opus-5`), Anthropic's most
capable model in the current lineup. Per Anthropic's guidance we enable
server-side refusal fallbacks by default so a rare safety refusal is
transparently retried on a compatible fallback model instead of
returning an error to the user.

Cost note: Opus 5 is the highest tier. For the narrative feature we
lower `effort` to "low" — a 3–4 paragraph trip summary does not need
deep reasoning, and low effort cuts token spend materially while
keeping response quality high. Downstream you can raise this per-call
if the prompt gets more complex.
"""

from __future__ import annotations

import logging
import os
from typing import Protocol

_log = logging.getLogger(__name__)


class LlmProvider(Protocol):
    async def generate_narrative(self, prompt: str) -> str:
        """Generate a natural-language trip narrative from a structured prompt."""
        ...


class MockLlmProvider:
    """Deterministic mock. Used in tests and whenever no API key is set.

    Echoes back a short summary derived from the prompt so callers can
    exercise the endpoint end-to-end without an ANTHROPIC_API_KEY.
    """

    async def generate_narrative(self, prompt: str) -> str:
        # Return the first 500 characters wrapped as a friendly note.
        trimmed = prompt.strip().replace("\n", " ")[:500]
        return (
            "This is a placeholder narrative (no ANTHROPIC_API_KEY is set). "
            "Structured trip data received:\n\n"
            f"{trimmed}…"
        )


class ClaudeLlmProvider:
    """Real Anthropic-backed provider using Claude Opus 5.

    Constructor is cheap; the actual `AsyncAnthropic` client is created
    lazily on first use so the module imports without side effects even
    when `anthropic` is not installed.
    """

    _MODEL = "claude-opus-5"
    _MAX_TOKENS = 2000
    _BETA_FALLBACKS = ["server-side-fallback-2026-07-01"]

    def __init__(self, *, model: str | None = None) -> None:
        self._model = model or self._MODEL
        self._client = None  # lazy

    def _get_client(self):
        if self._client is None:
            from anthropic import AsyncAnthropic  # imported lazily
            self._client = AsyncAnthropic()
        return self._client

    async def generate_narrative(self, prompt: str) -> str:
        client = self._get_client()
        response = await client.beta.messages.create(
            model=self._model,
            max_tokens=self._MAX_TOKENS,
            betas=self._BETA_FALLBACKS,
            fallbacks="default",
            output_config={"effort": "low"},
            messages=[{"role": "user", "content": prompt}],
        )

        # Refusal handling — the fallbacks parameter routes most safety
        # refusals to a compatible fallback model automatically, but a
        # residual refusal is still possible.
        if response.stop_reason == "refusal":
            _log.warning("Claude declined the narrative request")
            return (
                "The assistant could not generate a narrative for this trip. "
                "Please try a different origin/destination or check back later."
            )

        parts: list[str] = []
        for block in response.content:
            block_type = getattr(block, "type", None)
            if block_type == "text":
                parts.append(block.text)
        return "\n".join(parts).strip() or "(No narrative was generated.)"


def default_llm_provider() -> LlmProvider:
    """Pick the LLM provider based on runtime configuration.

    If `ANTHROPIC_API_KEY` is set, use the real Claude provider.
    Otherwise fall back to the mock so the app boots and tests pass
    without secrets. This keeps CI green without needing to inject
    fake env vars everywhere.
    """
    if os.environ.get("ANTHROPIC_API_KEY"):
        return ClaudeLlmProvider()
    return MockLlmProvider()
