"""Tests for the curated vehicle catalogue + refuel-window helper."""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.data.vehicle_models import VEHICLE_MODELS, all_models, find
from app.domain import FuelType
from app.main import app
from app.services.fuel_planning import refuel_window


client = TestClient(app)


def test_catalogue_has_target_coverage() -> None:
    """We promised the picker >= 20 vehicles across the top EU brands."""
    models = all_models()
    assert len(models) >= 20
    # Sanity: no duplicate ids.
    ids = [m.id for m in models]
    assert len(ids) == len(set(ids))
    # Must include the anchor makes we called out in the memory brief.
    makes = {m.make for m in models}
    for required in {
        "Volkswagen", "SEAT", "Renault", "Peugeot", "Citroën",
        "Opel", "Ford", "Toyota", "Hyundai", "Kia", "Dacia", "Fiat",
        "CUPRA",
    }:
        assert required in makes, f"missing anchor brand: {required}"


def test_catalogue_figures_are_sensible() -> None:
    """No zero / negative tanks or consumption sneaking through."""
    for m in VEHICLE_MODELS:
        assert 20 <= m.tank_liters <= 120, f"tank out of range for {m.id}"
        assert 3.0 <= m.consumption_l100km <= 15.0, (
            f"consumption out of range for {m.id}"
        )
        assert m.year_from >= 1990
        assert m.year_to is None or m.year_to >= m.year_from
        assert isinstance(m.fuel_type, FuelType)


def test_find_returns_none_for_unknown_id() -> None:
    assert find("does-not-exist") is None


def test_list_endpoint_returns_full_catalogue() -> None:
    r = client.get("/v1/vehicles")
    assert r.status_code == 200
    body = r.json()
    assert "vehicles" in body
    assert len(body["vehicles"]) == len(VEHICLE_MODELS)
    # Spot-check one entry serialises correctly.
    ids = {v["id"] for v in body["vehicles"]}
    assert "vw_golf_8" in ids


def test_get_by_id_endpoint() -> None:
    r = client.get("/v1/vehicles/vw_golf_8")
    assert r.status_code == 200
    body = r.json()
    assert body["id"] == "vw_golf_8"
    assert body["make"] == "Volkswagen"
    assert body["tank_liters"] > 0
    assert body["consumption_l100km"] > 0


def test_get_by_id_endpoint_404_on_unknown() -> None:
    r = client.get("/v1/vehicles/unknown-model")
    assert r.status_code == 404


def test_refuel_window_full_tank_shorter_than_range() -> None:
    """Full tank + 100 km trip = we reach the destination easily."""
    rw = refuel_window(
        route_distance_km=100.0,
        tank_level_frac=1.0,
        tank_liters=50,
        consumption_l100km=6.5,
    )
    assert rw.reaches_destination is True
    # Both milestones clamp to the route distance.
    assert rw.must_by_km == 100.0
    assert rw.comfortable_by_km == 100.0


def test_refuel_window_half_tank_long_trip() -> None:
    """Half tank + long trip = milestones sit somewhere on the route."""
    rw = refuel_window(
        route_distance_km=1000.0,
        tank_level_frac=0.5,
        tank_liters=50,
        consumption_l100km=6.5,
    )
    assert rw.reaches_destination is False
    # Half tank (25 L) minus 10 % reserve (5 L) → 20 L usable →
    # 20 / 6.5 * 100 ≈ 307 km.
    assert 290 < rw.must_by_km < 320
    # Comfortable = half tank minus 25 % reserve (12.5 L) → 12.5 L
    # usable → 12.5 / 6.5 * 100 ≈ 192 km.
    assert 180 < rw.comfortable_by_km < 210
    assert rw.comfortable_by_km <= rw.must_by_km


def test_refuel_window_defensive_against_zero_consumption() -> None:
    """A profile with junk consumption shouldn't crash the helper."""
    rw = refuel_window(
        route_distance_km=500.0,
        tank_level_frac=0.5,
        tank_liters=50,
        consumption_l100km=0.0,
    )
    # No crash; usable_range is astronomically large so we clamp.
    assert rw.reaches_destination is True
    assert rw.must_by_km == 500.0


def test_refuel_window_quarter_tank_normal_car() -> None:
    """1/4 tank on a small car — comfortable line should be 0 or
    very close (we already skipped the comfortable threshold), and
    must-by fits ~70 km of range."""
    rw = refuel_window(
        route_distance_km=800.0,
        tank_level_frac=0.25,
        tank_liters=45,
        consumption_l100km=6.0,
    )
    # 0.25 - 0.10 = 0.15 → 6.75 L usable → 6.75 / 6.0 * 100 = 112.5 km
    assert 100 < rw.must_by_km < 125
    # 0.25 - 0.25 = 0 → comfortable_by clamps at 0.
    assert rw.comfortable_by_km == 0.0
