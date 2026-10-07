"""Resend.com email sender.

Fire-and-forget: send() swallows errors so an email hiccup can't
break the primary request path. Configured via two env vars:

- `RESEND_API_KEY`  — obtain at resend.com after verifying the
  mytravelpal.io domain (three DNS records).
- `RESEND_FROM_ADDR` — sender identity, e.g.
  `MyTravelPal <no-reply@mytravelpal.io>`. Must be at a verified
  domain or Resend rejects.

`send_feedback_email` is used by `/v1/feedback` to forward each
suggestion to `hello@mytravelpal.io` right after it lands in the DB.
"""

from __future__ import annotations

import logging
import os

import httpx

_log = logging.getLogger(__name__)

_ENDPOINT = "https://api.resend.com/emails"
_TIMEOUT_S = 5.0


def _api_key() -> str | None:
    return os.getenv("RESEND_API_KEY") or None


def _from_addr() -> str:
    return os.getenv("RESEND_FROM_ADDR") or "MyTravelPal <no-reply@mytravelpal.io>"


async def send_email(
    *,
    to: str | list[str],
    subject: str,
    text: str,
    reply_to: str | None = None,
    attachments: list[dict] | None = None,
) -> bool:
    """POST to Resend. Returns True on success, False on any error
    (network, non-2xx, missing key). Never raises.

    `attachments` is a list of Resend attachment dicts:
    [{"filename": "screenshot.png", "content": "<base64>"}]
    """
    key = _api_key()
    if not key:
        _log.info("Resend disabled (no RESEND_API_KEY); skipping email")
        return False
    payload: dict = {
        "from": _from_addr(),
        "to": [to] if isinstance(to, str) else list(to),
        "subject": subject,
        "text": text,
    }
    if reply_to:
        payload["reply_to"] = reply_to
    if attachments:
        payload["attachments"] = attachments
    try:
        async with httpx.AsyncClient(timeout=_TIMEOUT_S) as http:
            r = await http.post(
                _ENDPOINT,
                headers={
                    "Authorization": f"Bearer {key}",
                    "Content-Type": "application/json",
                },
                json=payload,
            )
        if r.status_code >= 400:
            _log.warning(
                "Resend HTTP %s: %s", r.status_code, r.text[:200],
            )
            return False
        return True
    except Exception as exc:  # noqa: BLE001
        _log.warning("Resend request failed: %r", exc)
        return False
