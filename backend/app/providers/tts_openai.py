"""OpenAI Text-to-Speech provider for trip narrative audio.

Uses the OpenAI TTS API (model tts-1 / tts-1-hd) to synthesize
natural-sounding audio from the narrative text. Returns raw MP3 bytes.

Falls back gracefully when OPENAI_API_KEY is not set — the caller
receives None and the mobile client uses device TTS instead.
"""

from __future__ import annotations

import logging
import os

_log = logging.getLogger(__name__)

# Voice options by character/gender preference.
# nova → warm, friendly female (default for travel)
# shimmer → soft female
# alloy → neutral
# echo → male, conversational
# fable → British male
# onyx → deep male
DEFAULT_VOICE = "nova"
DEFAULT_MODEL = "tts-1-hd"  # Higher quality; tts-1 is faster but more robotic


async def synthesize(
    text: str,
    *,
    voice: str = DEFAULT_VOICE,
    model: str = DEFAULT_MODEL,
    speed: float = 1.0,
) -> bytes | None:
    """Synthesize *text* to MP3 bytes using OpenAI TTS.

    Returns ``None`` when the API key is absent or the call fails,
    so callers can degrade to device TTS without crashing.
    """
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        _log.debug("OPENAI_API_KEY not set — TTS unavailable, client will use device TTS")
        return None

    try:
        from openai import AsyncOpenAI  # imported lazily so the module
        # loads even when the openai package isn't installed yet.
        client = AsyncOpenAI(api_key=api_key)
        response = await client.audio.speech.create(
            model=model,
            voice=voice,  # type: ignore[arg-type]
            input=text,
            response_format="mp3",
            speed=max(0.25, min(4.0, speed)),
        )
        # The response object exposes the raw bytes via `.content`.
        return response.content
    except Exception as exc:  # noqa: BLE001
        _log.warning("OpenAI TTS synthesis failed: %r", exc)
        return None
