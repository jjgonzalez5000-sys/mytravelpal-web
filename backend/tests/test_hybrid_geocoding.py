from __future__ import annotations

import pytest

from app.domain import Coordinate, Country
from app.providers.geocoding import (
    GeocodeResult,
    HybridGeocodingProvider,
)


class _StubProvider:
    def __init__(self, results: tuple[GeocodeResult, ...]) -> None:
        self._results = results
        self.calls = 0

    async def search(self, query: str, *, limit: int = 5) -> tuple[GeocodeResult, ...]:
        self.calls += 1
        return self._results[:limit]


_BERN = GeocodeResult("Bern, Switzerland", Coordinate(46.9481, 7.4474), Country.CH)
_UNTERAGERI = GeocodeResult(
    "Unterägeri, Zug, Switzerland", Coordinate(47.135, 8.578), Country.CH
)


@pytest.mark.asyncio
async def test_hybrid_returns_primary_hits_without_calling_fallback() -> None:
    primary = _StubProvider((_BERN,))
    fallback = _StubProvider((_UNTERAGERI,))
    hybrid = HybridGeocodingProvider(primary, fallback)

    results = await hybrid.search("bern")
    assert results == (_BERN,)
    assert primary.calls == 1
    assert fallback.calls == 0


@pytest.mark.asyncio
async def test_hybrid_falls_back_when_primary_returns_empty() -> None:
    primary = _StubProvider(())
    fallback = _StubProvider((_UNTERAGERI,))
    hybrid = HybridGeocodingProvider(primary, fallback)

    results = await hybrid.search("unteraegeri")
    assert results == (_UNTERAGERI,)
    assert primary.calls == 1
    assert fallback.calls == 1


@pytest.mark.asyncio
async def test_hybrid_returns_empty_when_both_are_empty() -> None:
    primary = _StubProvider(())
    fallback = _StubProvider(())
    hybrid = HybridGeocodingProvider(primary, fallback)

    assert await hybrid.search("nowhere") == ()
