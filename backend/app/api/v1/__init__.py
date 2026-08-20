from fastapi import APIRouter

from app.api.v1 import geocode, trips

router = APIRouter()
router.include_router(trips.router)
router.include_router(geocode.router)
