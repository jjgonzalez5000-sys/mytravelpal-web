"""User feedback / suggestions endpoint.

POST /v1/feedback — free-form suggestion the driver enters from the
What's-new sheet or Settings. Persists to Postgres when the DB is
configured; otherwise no-op (feedback lost in local dev is fine, we
just want the mobile call not to fail).

Auth is required so we always attach `user_id` for follow-up via
Play Console messaging. `reply_email` is optional — set only when
the user ticks "quiero respuesta" in the sheet.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy import text

from app.auth.dependency import current_user_required
from app.auth.jwt import AuthUser
from app.db import get_session, is_available as db_available

_log = logging.getLogger(__name__)

router = APIRouter(prefix="/feedback", tags=["feedback"])


class FeedbackPayload(BaseModel):
    body_text: str = Field(..., min_length=3, max_length=4000)
    app_version: str = Field(..., min_length=1, max_length=64)
    locale: str = Field(..., min_length=2, max_length=16)
    platform: str = Field(default="android", min_length=1, max_length=32)
    category: str = Field(default="suggestion", min_length=1, max_length=32)
    reply_email: str | None = Field(default=None, max_length=254)
    # Base64-encoded PNG/JPG screenshots. Max 3, each capped at 2 MB
    # by the email provider's attachment limit.
    attachments: list[str] = Field(default_factory=list, max_length=3)


class FeedbackReceipt(BaseModel):
    id: int
    accepted: bool
    message: str


@router.post("", response_model=FeedbackReceipt, status_code=status.HTTP_201_CREATED)
async def submit_feedback(
    payload: FeedbackPayload,
    user: AuthUser = Depends(current_user_required),
) -> FeedbackReceipt:
    if not db_available():
        _log.info(
            "feedback (db unavailable) user=%s ver=%s body=%s",
            user.id, payload.app_version, payload.body_text[:80],
        )
        # 201 with accepted=False so mobile still shows the "gracias"
        # confirmation — losing a dev-mode message is not a user-
        # facing failure.
        return FeedbackReceipt(id=0, accepted=False, message="stored in log")
    try:
        async with get_session() as session:
            result = await session.execute(
                text(
                    """
                    INSERT INTO feedback (
                        user_id, app_version, locale, platform,
                        category, body_text, reply_email
                    )
                    VALUES (
                        :user_id, :app_version, :locale, :platform,
                        :category, :body_text, :reply_email
                    )
                    RETURNING id
                    """
                ),
                {
                    "user_id": user.id,
                    "app_version": payload.app_version,
                    "locale": payload.locale,
                    "platform": payload.platform,
                    "category": payload.category,
                    "body_text": payload.body_text,
                    "reply_email": payload.reply_email,
                },
            )
            row_id = result.scalar_one()
            await session.commit()
    except Exception as exc:  # noqa: BLE001
        _log.warning("feedback insert failed: %r", exc)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail={"error": "feedback_store_unavailable"},
        )

    # Fire-and-forget email to the ops mailbox with the full context.
    # Never blocks the response nor raises — a Resend hiccup can't
    # break the driver's UX.
    import os
    from app.providers.email_resend import send_email
    to_addr = os.getenv("FEEDBACK_EMAIL_TO") or "hello@mytravelpal.io"
    subject_prefix = (
        "[MTP feedback"
        + (f" reply-wanted]" if payload.reply_email else "]")
    )
    subject = (
        f"{subject_prefix} {payload.body_text[:60].replace(chr(10), ' ')}"
    )
    body = (
        f"New suggestion from tester\n"
        f"----------------------------------------\n\n"
        f"{payload.body_text}\n\n"
        f"----------------------------------------\n"
        f"user_id       : {user.id}\n"
        f"email (auth)  : {user.email}\n"
        f"reply_email   : {payload.reply_email or '(not provided)'}\n"
        f"app_version   : {payload.app_version}\n"
        f"platform      : {payload.platform}\n"
        f"locale        : {payload.locale}\n"
        f"category      : {payload.category}\n"
        f"feedback_id   : {row_id}\n"
    )
    # Build Resend attachment list from base64 screenshots.
    email_attachments = [
        {"filename": f"screenshot_{i+1}.jpg", "content": b64}
        for i, b64 in enumerate(payload.attachments[:3])
    ] if payload.attachments else None

    if email_attachments:
        body += f"\n\nAttachments: {len(email_attachments)} screenshot(s) included.\n"

    try:
        await send_email(
            to=to_addr,
            subject=subject,
            text=body,
            reply_to=payload.reply_email,
            attachments=email_attachments,
        )
    except Exception as exc:  # noqa: BLE001
        _log.warning("feedback email send failed: %r", exc)

    return FeedbackReceipt(
        id=int(row_id), accepted=True, message="thanks",
    )
