"""Profile endpoint tests, focused on the GDPR delete-account flow.

The suite exercises the in-memory fallback path (no DATABASE_URL set)
so it can run in CI without a Postgres. The prod code path is the
same shape — reordered DELETEs + explicit try/except so any DB error
lands in `fly logs` — but that path is verified manually against
Fly Postgres.
"""

from __future__ import annotations

from fastapi.testclient import TestClient

from app.auth.jwt import AuthUser, issue_token
from app.main import app

client = TestClient(app)


def _auth(user_id: str = "demo:jane@example.com") -> dict[str, str]:
    """Mint a bearer header for `user_id`."""
    token = issue_token(
        AuthUser(
            id=user_id, email=user_id, display_name="Jane", provider="demo",
        )
    )
    return {"Authorization": f"Bearer {token}"}


class TestDeleteAccount:
    def test_delete_returns_200(self) -> None:
        r = client.delete("/v1/profile", headers=_auth("demo:d1@x"))
        assert r.status_code == 200, r.text
        assert r.json() == {"status": "deleted"}

    def test_delete_wipes_profile(self) -> None:
        h = _auth("demo:d2@x")
        # Put a profile in
        r = client.put("/v1/profile", headers=h, json={
            "profile": {"favouriteFood": "tapas"},
        })
        assert r.status_code == 200
        # Confirm it's there
        r = client.get("/v1/profile", headers=h)
        assert r.json()["profile"] == {"favouriteFood": "tapas"}
        # Delete
        r = client.delete("/v1/profile", headers=h)
        assert r.status_code == 200
        # Should be gone
        r = client.get("/v1/profile", headers=h)
        assert r.json()["profile"] is None

    def test_delete_wipes_saved_trips(self) -> None:
        h = _auth("demo:d3@x")
        # Save a couple of trips
        r = client.put("/v1/profile/trips", headers=h, json={
            "trips": [
                {"id": "t1", "origin": "Madrid", "destination": "Lisboa"},
                {"id": "t2", "origin": "Roma", "destination": "Milano"},
            ],
        })
        assert r.status_code == 200
        # Confirm they landed
        r = client.get("/v1/profile/trips", headers=h)
        assert len(r.json()["trips"]) == 2
        # Delete the account
        r = client.delete("/v1/profile", headers=h)
        assert r.status_code == 200
        # Trips should be gone too
        r = client.get("/v1/profile/trips", headers=h)
        assert r.json()["trips"] == []

    def test_delete_requires_bearer(self) -> None:
        r = client.delete("/v1/profile")
        # 401 without an Authorization header — the account can't
        # be deleted without proving who's asking.
        assert r.status_code == 401

    def test_delete_rejects_bad_token(self) -> None:
        r = client.delete(
            "/v1/profile",
            headers={"Authorization": "Bearer not-a-real-jwt"},
        )
        assert r.status_code == 401

    def test_delete_isolates_users(self) -> None:
        """Deleting Jane's account must not touch John's data."""
        jane = _auth("demo:jane@iso.x")
        john = _auth("demo:john@iso.x")
        client.put("/v1/profile", headers=jane, json={
            "profile": {"who": "jane"},
        })
        client.put("/v1/profile", headers=john, json={
            "profile": {"who": "john"},
        })
        # Delete jane
        r = client.delete("/v1/profile", headers=jane)
        assert r.status_code == 200
        # John's still there
        r = client.get("/v1/profile", headers=john)
        assert r.json()["profile"] == {"who": "john"}

    def test_delete_is_idempotent(self) -> None:
        """A second DELETE for the same user should still succeed
        even though there's nothing left to delete — matches the
        client behaviour of retrying on flaky networks."""
        h = _auth("demo:idem@x")
        client.put("/v1/profile", headers=h, json={
            "profile": {"foo": "bar"},
        })
        r1 = client.delete("/v1/profile", headers=h)
        r2 = client.delete("/v1/profile", headers=h)
        assert r1.status_code == 200
        assert r2.status_code == 200
