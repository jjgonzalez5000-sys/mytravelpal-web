from fastapi import APIRouter

from app.api.v1 import (
    adverse_events,
    attributions,
    auth,
    diagnostics,
    geocode,
    narrative,
    trips,
)

router = APIRouter()
router.include_router(trips.router)
router.include_router(geocode.router)
router.include_router(adverse_events.router)
router.include_router(narrative.router)
router.include_router(auth.router)
router.include_router(diagnostics.router)
router.include_router(attributions.router)
