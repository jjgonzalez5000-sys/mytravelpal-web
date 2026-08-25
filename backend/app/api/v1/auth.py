from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from app.auth.dependency import current_user_required
from app.auth.jwt import AuthUser, issue_token
from app.auth.providers import OAuthPayload, OAuthVerificationError, get_provider

router = APIRouter(prefix="/auth", tags=["auth"])


class SessionRequest(BaseModel):
    provider: str = Field(description="google | facebook | demo")
    id_token: str = Field(min_length=1, max_length=8192)
    demo_email: str | None = Field(default=None, max_length=254)
    demo_name: str | None = Field(default=None, max_length=100)


class SessionResponse(BaseModel):
    token: str
    user: "UserOut"


class UserOut(BaseModel):
    id: str
    email: str
    display_name: str
    provider: str

    @classmethod
    def from_domain(cls, u: AuthUser) -> "UserOut":
        return cls(
            id=u.id, email=u.email,
            display_name=u.display_name, provider=u.provider,
        )


@router.post("/session", response_model=SessionResponse)
async def create_session(payload: SessionRequest) -> SessionResponse:
    try:
        provider = get_provider(payload.provider)
        user = await provider.verify(OAuthPayload(
            id_token=payload.id_token,
            demo_email=payload.demo_email,
            demo_name=payload.demo_name,
        ))
    except OAuthVerificationError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"error": "oauth_verification_failed", "message": str(exc)},
        ) from exc
    return SessionResponse(token=issue_token(user), user=UserOut.from_domain(user))


@router.get("/me", response_model=UserOut)
async def me(user: AuthUser = Depends(current_user_required)) -> UserOut:
    return UserOut.from_domain(user)


SessionResponse.model_rebuild()
