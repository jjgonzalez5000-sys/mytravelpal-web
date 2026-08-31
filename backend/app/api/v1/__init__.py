from fastapi import APIRouter

from app.api.v1 import (
    adverse_events,
    attributions,
    auth,
    companion,
    diagnostics,
    geocode,
    inspire,
    narrative,
    profile,
    trips,
    weather,
)

router = APIRouter()
router.include_router(trips.router)
router.include_router(geocode.router)
router.include_router(adverse_events.router)
router.include_router(narrative.router)
router.include_router(auth.router)
router.include_router(profile.router)
router.include_router(companion.router)
router.include_router(inspire.router)
router.include_router(weather.router)
router.include_router(diagnostics.router)
router.include_router(attributions.router)
