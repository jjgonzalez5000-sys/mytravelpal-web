"""Garage (multi-vehicle) CRUD + `/plan` `garage_vehicle_id` resolution.

Uses the in-memory profile store (no DATABASE_URL) so tests stay
hermetic. The prod code path is the same shape — same helpers
`_read_profile` / `_write_profile` — so covering the fallback path
exercises the JSON blob handling too.
"""

from __future__ import annotations

from datetime import datetime, timezone

from fastapi.testclient import TestClient

from app.api.v1.profile import _PROFILES
from app.auth.jwt import AuthUser, issue_token
from app.main import app

client = TestClient(app)


def _auth(user_id: str) -> dict[str, str]:
    token = issue_token(
        AuthUser(
            id=user_id, email=user_id, display_name="Jane", provider="demo",
        )
    )
    return {"Authorization": f"Bearer {token}"}


def setup_function(_fn) -> None:
    _PROFILES.clear()


class TestGarageCrud:
    def test_empty_garage_returns_empty_list(self) -> None:
        r = client.get("/v1/profile/garage", headers=_auth("demo:g0@x"))
        assert r.status_code == 200
        assert r.json() == {"vehicles": []}

    def test_add_vehicle_generates_uuid_and_persists(self) -> None:
        h = _auth("demo:g1@x")
        r = client.post(
            "/v1/profile/garage",
            headers=h,
            json={
                "name": "Mi Golf",
                "model_id": "vw_golf_8_diesel",
                "default_tank_percent": 75,
                "notes": "El de diario",
            },
        )
        assert r.status_code == 200, r.text
        body = r.json()
        assert body["id"]
        assert body["name"] == "Mi Golf"
        assert body["model_id"] == "vw_golf_8_diesel"
        assert body["default_tank_percent"] == 75
        assert body["notes"] == "El de diario"

        # Re-fetch — round-trips exactly.
        r = client.get("/v1/profile/garage", headers=h)
        assert r.status_code == 200
        vehicles = r.json()["vehicles"]
        assert len(vehicles) == 1
        assert vehicles[0]["id"] == body["id"]

    def test_add_multiple_vehicles_unique_ids(self) -> None:
        h = _auth("demo:g2@x")
        first = client.post(
            "/v1/profile/garage",
            headers=h,
            json={"name": "Golf", "model_id": "vw_golf_8", "default_tank_percent": 100},
        ).json()
        second = client.post(
            "/v1/profile/garage",
            headers=h,
            json={"name": "León", "model_id": "seat_leon_4", "default_tank_percent": 50},
        ).json()
        assert first["id"] != second["id"]
        r = client.get("/v1/profile/garage", headers=h)
        assert len(r.json()["vehicles"]) == 2

    def test_add_rejects_unknown_model_id(self) -> None:
        h = _auth("demo:g3@x")
        r = client.post(
            "/v1/profile/garage",
            headers=h,
            json={"name": "Bad", "model_id": "not-a-real-car"},
        )
        assert r.status_code == 400
        assert r.json()["detail"]["error"] == "unknown_vehicle_model"

    def test_add_rejects_empty_name(self) -> None:
        h = _auth("demo:g4@x")
        r = client.post(
            "/v1/profile/garage",
            headers=h,
            json={"name": "", "model_id": "vw_golf_8"},
        )
        # Pydantic 422 for the min_length violation.
        assert r.status_code == 422

    def test_update_partial_fields(self) -> None:
        h = _auth("demo:g5@x")
        created = client.post(
            "/v1/profile/garage",
            headers=h,
            json={"name": "Original", "model_id": "vw_golf_8", "default_tank_percent": 50},
        ).json()
        vid = created["id"]
        # PUT only name — other fields unchanged.
        r = client.put(
            f"/v1/profile/garage/{vid}",
            headers=h,
            json={"name": "Renamed"},
        )
        assert r.status_code == 200
        body = r.json()
        assert body["name"] == "Renamed"
        assert body["default_tank_percent"] == 50  # untouched
        # PUT tank + notes.
        r = client.put(
            f"/v1/profile/garage/{vid}",
            headers=h,
            json={"default_tank_percent": 25, "notes": "Casi vacío"},
        )
        assert r.status_code == 200
        body = r.json()
        assert body["default_tank_percent"] == 25
        assert body["notes"] == "Casi vacío"
        assert body["name"] == "Renamed"

    def test_update_unknown_id_returns_404(self) -> None:
        h = _auth("demo:g6@x")
        r = client.put(
            "/v1/profile/garage/does-not-exist",
            headers=h,
            json={"name": "Nope"},
        )
        assert r.status_code == 404

    def test_delete_removes_entry(self) -> None:
        h = _auth("demo:g7@x")
        first = client.post(
            "/v1/profile/garage",
            headers=h,
            json={"name": "A", "model_id": "vw_golf_8"},
        ).json()
        second = client.post(
            "/v1/profile/garage",
            headers=h,
            json={"name": "B", "model_id": "vw_polo_6"},
        ).json()
        r = client.delete(
            f"/v1/profile/garage/{first['id']}", headers=h,
        )
        assert r.status_code == 200
        vehicles = client.get("/v1/profile/garage", headers=h).json()["vehicles"]
        assert len(vehicles) == 1
        assert vehicles[0]["id"] == second["id"]

    def test_delete_unknown_id_returns_404(self) -> None:
        h = _auth("demo:g8@x")
        r = client.delete("/v1/profile/garage/none", headers=h)
        assert r.status_code == 404

    def test_garage_requires_bearer(self) -> None:
        r = client.get("/v1/profile/garage")
        assert r.status_code == 401
        r = client.post(
            "/v1/profile/garage",
            json={"name": "x", "model_id": "vw_golf_8"},
        )
        assert r.status_code == 401

    def test_garage_isolates_users(self) -> None:
        jane = _auth("demo:iso-jane@x")
        john = _auth("demo:iso-john@x")
        client.post(
            "/v1/profile/garage",
            headers=jane,
            json={"name": "Jane car", "model_id": "vw_golf_8"},
        )
        assert client.get("/v1/profile/garage", headers=john).json() == {
            "vehicles": []
        }
        assert len(client.get("/v1/profile/garage", headers=jane)
                   .json()["vehicles"]) == 1


class TestGarageLegacyMigration:
    def test_returning_user_with_legacy_single_vehicle_synthesised(self) -> None:
        h = _auth("demo:legacy@x")
        # Pre-seed the profile blob exactly as an older client would:
        # single `vehicle_model_id` + `current_tank_level_percent`,
        # no `garage` key.
        client.put(
            "/v1/profile",
            headers=h,
            json={
                "profile": {
                    "travellers": 2,
                    "vehicle_model_id": "vw_golf_8_diesel",
                    "current_tank_level_percent": 50,
                }
            },
        )
        r = client.get("/v1/profile/garage", headers=h)
        assert r.status_code == 200
        vehicles = r.json()["vehicles"]
        assert len(vehicles) == 1
        assert vehicles[0]["model_id"] == "vw_golf_8_diesel"
        assert vehicles[0]["default_tank_percent"] == 50
        # Second read should still return exactly one entry (migration
        # is idempotent — the synthesised list is persisted on the
        # first call).
        r = client.get("/v1/profile/garage", headers=h)
        vehicles2 = r.json()["vehicles"]
        assert len(vehicles2) == 1
        assert vehicles2[0]["id"] == vehicles[0]["id"]

    def test_legacy_missing_fields_returns_empty(self) -> None:
        h = _auth("demo:legacy-empty@x")
        client.put(
            "/v1/profile",
            headers=h,
            json={"profile": {"travellers": 1}},
        )
        r = client.get("/v1/profile/garage", headers=h)
        assert r.status_code == 200
        assert r.json() == {"vehicles": []}


class TestPlanResolvesGarageVehicle:
    """`/plan` should look up `garage_vehicle_id` on the caller's
    garage and produce a `refuel_window` in the response.
    """

    def _plan_body(
        self,
        *,
        garage_vehicle_id: str | None,
        tank_override: int | None = None,
    ) -> dict:
        body: dict = {
            "origin": {"lat": 40.4168, "lon": -3.7038},   # Madrid
            "destination": {"lat": 41.3874, "lon": 2.1686},  # Barcelona
            "desired_departure_at": datetime.now(timezone.utc).isoformat(),
            "trip_profile": {
                "travellers": 2,
                "vehicle": {
                    "type": "car",
                    "fuel_type": "petrol",
                    "fuel_tank_l": 50,
                    "consumption_l_per_100km": 6.5,
                },
            },
        }
        if garage_vehicle_id is not None:
            body["garage_vehicle_id"] = garage_vehicle_id
        if tank_override is not None:
            body["trip_profile"]["current_tank_level_percent"] = tank_override
        return body

    def test_plan_uses_garage_entry_for_refuel_window(self) -> None:
        h = _auth("demo:plan-garage@x")
        created = client.post(
            "/v1/profile/garage",
            headers=h,
            json={
                "name": "Golf",
                "model_id": "vw_golf_8_diesel",
                "default_tank_percent": 50,
            },
        ).json()
        r = client.post(
            "/v1/trips/plan",
            headers=h,
            json=self._plan_body(garage_vehicle_id=created["id"]),
        )
        assert r.status_code == 200, r.text
        window = r.json().get("refuel_window")
        assert window is not None
        assert window["usable_range_km"] > 0

    def test_plan_ignores_unknown_garage_id(self) -> None:
        """An unknown id falls through to the legacy pair — since
        we didn't send one, there should be no `refuel_window`."""
        h = _auth("demo:plan-garage-bad@x")
        r = client.post(
            "/v1/trips/plan",
            headers=h,
            json=self._plan_body(garage_vehicle_id="not-a-real-uuid"),
        )
        assert r.status_code == 200, r.text
        assert r.json().get("refuel_window") is None

    def test_plan_without_auth_ignores_garage_id(self) -> None:
        # No Authorization header → we can't look up the garage, so
        # the field is ignored and no refuel_window is produced.
        r = client.post(
            "/v1/trips/plan",
            json=self._plan_body(garage_vehicle_id="some-id"),
        )
        assert r.status_code == 200, r.text
        assert r.json().get("refuel_window") is None

    def test_plan_client_override_wins_over_garage_default(self) -> None:
        h = _auth("demo:plan-override@x")
        created = client.post(
            "/v1/profile/garage",
            headers=h,
            json={
                "name": "Golf",
                "model_id": "vw_golf_8_diesel",
                "default_tank_percent": 100,
            },
        ).json()
        # Full tank in the garage but 25% override for THIS trip →
        # smaller usable range than the 100 % baseline.
        r_full = client.post(
            "/v1/trips/plan",
            headers=h,
            json=self._plan_body(garage_vehicle_id=created["id"]),
        ).json()["refuel_window"]
        r_override = client.post(
            "/v1/trips/plan",
            headers=h,
            json=self._plan_body(
                garage_vehicle_id=created["id"], tank_override=25,
            ),
        ).json()["refuel_window"]
        assert r_full is not None and r_override is not None
        assert r_override["usable_range_km"] < r_full["usable_range_km"]
