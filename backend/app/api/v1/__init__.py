from fastapi import APIRouter

from app.api.v1 import (
    adverse_events,
    attributions,
    auth,
    billing,
    companion,
    companion_session,
    diagnostics,
    feedback,
    geocode,
    inspire,
    narrative,
    parking,
    places,
    profile,
    speed_cameras,
    suggest,
    trip_sharing,
    trips,
    vehicles,
    weather,
)

router = APIRouter()
router.include_router(trips.router)
router.include_router(trip_sharing.router)
router.include_router(suggest.router)
router.include_router(geocode.router)
router.include_router(adverse_events.router)
router.include_router(narrative.router)
router.include_router(auth.router)
router.include_router(profile.router)
router.include_router(companion.router)
router.include_router(companion_session.router)
router.include_router(inspire.router)
router.include_router(parking.router)
router.include_router(places.router)
router.include_router(speed_cameras.router)
router.include_router(weather.router)
router.include_router(diagnostics.router)
router.include_router(attributions.router)
router.include_router(vehicles.router)
router.include_router(feedback.router)
router.include_router(billing.router)
