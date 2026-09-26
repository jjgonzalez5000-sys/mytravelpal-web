"""Read-only endpoints for the curated top-EU vehicle catalogue.

The mobile app pulls the full list on cold-start (small payload,
~50 rows), caches it locally and lets the user pick their model as a
shortcut for setting `fuel_tank_l` + `consumption_l_per_100km` in the
profile.

The catalogue is a static Python literal (`app.data.vehicle_models`)
so there's no I/O — the endpoint is essentially serialization. `Cache-
Control: public, max-age=86400` because the list only changes on a
deploy and the CDN can safely hold it for a day.
"""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, Response, status
from pydantic import BaseModel

from app.data.vehicle_models import all_models, find
from app.domain import FuelType

router = APIRouter(prefix="/vehicles", tags=["vehicles"])


class VehicleModelOut(BaseModel):
    id: str
    make: str
    model: str
    year_from: int
    year_to: int | None = None
    fuel_type: FuelType
    tank_liters: float
    consumption_l100km: float


class VehiclesListResponse(BaseModel):
    vehicles: list[VehicleModelOut]


def _to_out(v) -> VehicleModelOut:
    return VehicleModelOut(
        id=v.id,
        make=v.make,
        model=v.model,
        year_from=v.year_from,
        year_to=v.year_to,
        fuel_type=v.fuel_type,
        tank_liters=v.tank_liters,
        consumption_l100km=v.consumption_l100km,
    )


@router.get("", response_model=VehiclesListResponse)
async def list_vehicles(response: Response) -> VehiclesListResponse:
    # Cacheable for a day. Any change requires a redeploy anyway.
    response.headers["Cache-Control"] = "public, max-age=86400"
    return VehiclesListResponse(vehicles=[_to_out(v) for v in all_models()])


@router.get("/{model_id}", response_model=VehicleModelOut)
async def get_vehicle(model_id: str, response: Response) -> VehicleModelOut:
    v = find(model_id)
    if v is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": "unknown_vehicle_model", "id": model_id},
        )
    response.headers["Cache-Control"] = "public, max-age=86400"
    return _to_out(v)
