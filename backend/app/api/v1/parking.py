"""Parking POI search endpoint.

`POST /v1/pois/parking` — find parking near a coordinate. Used
both from the trip flow (per-waypoint parking chip) and as a
standalone "I'm going to an event" lookup from the mobile home
screen. Requires the app API key (rate-limit + abuse gate);
Google Sign-In JWT is NOT required — parking search is a public
utility feature.
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, Query
from pydantic import BaseModel, Field

from app.providers.parking import GeoapifyParkingProvider

router = APIRouter(prefix="/pois", tags=["pois"])
_log = logging.getLogger(__name__)


class ParkingOut(BaseModel):
    name: str
    lat: float
    lon: float
    country: str
    distance_from_query_km: float
    price_eur_per_hour: float | None = None
    max_stay_hours: float | None = None
    covered: bool | None = None
    capacity: int | None = None
    kind: str = "surface"
    kid_friendly: bool | None = None
    dogs_allowed: bool | None = None
    toilets: bool | None = None
    showers: bool | None = None
    food_nearby: bool | None = None
    ev_charging: bool | None = None
    fuel_station: bool | None = None
    wheelchair_access: bool | None = None
    supervised: bool | None = None
    rv_friendly: bool | None = None
    truck_friendly: bool | None = None
    park_and_ride: bool | None = None
    attributes: dict[str, str] = Field(default_factory=dict)


class ParkingListOut(BaseModel):
    parkings: list[ParkingOut]


@router.post("/parking", response_model=ParkingListOut)
async def search_parking(
    lat: float = Query(..., ge=-90.0, le=90.0),
    lon: float = Query(..., ge=-180.0, le=180.0),
    radius_km: float = Query(2.0, gt=0.0, le=20.0),
    limit: int = Query(20, gt=0, le=50),
    # Amenity filters — client sends `true` only for amenities the
    # driver actually wants. Filter is `True`-only: parkings with
    # `None` (unknown) pass through so we don't over-shrink the
    # list to venues that happen to have OSM tags. When the user
    # unchecks all, no filter is applied.
    require_kid_friendly: bool = Query(False),
    require_dogs: bool = Query(False),
    require_toilets: bool = Query(False),
    require_showers: bool = Query(False),
    require_food: bool = Query(False),
    require_ev: bool = Query(False),
    require_fuel: bool = Query(False),
    require_wheelchair: bool = Query(False),
    require_rv: bool = Query(False),
    require_truck: bool = Query(False),
) -> ParkingListOut:
    from app.domain import Coordinate

    provider = GeoapifyParkingProvider()
    results = await provider.parking_near(
        Coordinate(lat=lat, lon=lon), radius_km=radius_km,
    )
    def _passes(p) -> bool:
        # True-only match: `None` (unknown) always passes; `False`
        # (OSM says no) filters OUT; `True` matches.
        if require_kid_friendly and p.kid_friendly is False:
            return False
        if require_kid_friendly and p.kid_friendly is None:
            return False
        if require_dogs and p.dogs_allowed is not True:
            return False
        if require_toilets and p.toilets is not True:
            return False
        if require_showers and p.showers is not True:
            return False
        if require_food and p.food_nearby is not True:
            return False
        if require_ev and p.ev_charging is not True:
            return False
        if require_fuel and p.fuel_station is not True:
            return False
        if require_wheelchair and p.wheelchair_access is not True:
            return False
        if require_rv and p.rv_friendly is not True:
            return False
        if require_truck and p.truck_friendly is not True:
            return False
        return True
    filtered = [p for p in results if _passes(p)]
    trimmed = filtered[:limit]
    return ParkingListOut(
        parkings=[
            ParkingOut(
                name=p.name,
                lat=p.coordinate.lat,
                lon=p.coordinate.lon,
                country=p.country.value,
                distance_from_query_km=round(p.distance_from_query_km, 3),
                price_eur_per_hour=p.price_eur_per_hour,
                max_stay_hours=p.max_stay_hours,
                covered=p.covered,
                capacity=p.capacity,
                kind=p.kind,
                kid_friendly=p.kid_friendly,
                dogs_allowed=p.dogs_allowed,
                toilets=p.toilets,
                showers=p.showers,
                food_nearby=p.food_nearby,
                ev_charging=p.ev_charging,
                fuel_station=p.fuel_station,
                wheelchair_access=p.wheelchair_access,
                supervised=p.supervised,
                rv_friendly=p.rv_friendly,
                truck_friendly=p.truck_friendly,
                park_and_ride=p.park_and_ride,
                attributes=dict(p.attributes),
            )
            for p in trimmed
        ],
    )
