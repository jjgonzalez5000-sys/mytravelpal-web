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

    async def search(
        self, query: str, *, limit: int = 5, lang: str | None = None,
    ) -> tuple[GeocodeResult, ...]:
        del lang  # stub ignores locale — real providers honour it
        self.calls += 1
        return self._results[:limit]

    async def reverse(
        self, lat: float, lon: float, *, lang: str | None = None,
    ) -> GeocodeResult | None:
        del lat, lon, lang
        return None


_BERN = GeocodeResult("Bern, Switzerland", Coordinate(46.9481, 7.4474), Country.CH)
_UNTERAGERI = GeocodeResult(
    "Unterägeri, Zug, Switzerland", Coordinate(47.135, 8.578), Country.CH
)


@pytest.mark.asyncio
async def test_hybrid_short_query_hits_only_primary() -> None:
    """Queries shorter than 3 chars stay local — cheap prefix typing."""
    primary = _StubProvider((_BERN,))
    fallback = _StubProvider((_UNTERAGERI,))
    hybrid = HybridGeocodingProvider(primary, fallback)

    results = await hybrid.search("be")
    assert results == (_BERN,)
    assert primary.calls == 1
    assert fallback.calls == 0


@pytest.mark.asyncio
async def test_hybrid_merges_primary_and_fallback_on_longer_queries() -> None:
    """3+ char queries merge results from both providers, primary first."""
    primary = _StubProvider((_BERN,))
    fallback = _StubProvider((_UNTERAGERI,))
    hybrid = HybridGeocodingProvider(primary, fallback)

    results = await hybrid.search("bern")
    assert results == (_BERN, _UNTERAGERI)
    assert primary.calls == 1
    assert fallback.calls == 1


@pytest.mark.asyncio
async def test_hybrid_returns_fallback_when_primary_returns_empty() -> None:
    primary = _StubProvider(())
    fallback = _StubProvider((_UNTERAGERI,))
    hybrid = HybridGeocodingProvider(primary, fallback)

    results = await hybrid.search("unteraegeri")
    assert results == (_UNTERAGERI,)
    assert primary.calls == 1
    assert fallback.calls == 1


@pytest.mark.asyncio
async def test_hybrid_dedupes_identical_display_names() -> None:
    """When both providers return the same city (e.g. Bern in the mock
    AND in Nominatim), only the primary one shows so we don't confuse
    users with two identical rows.
    """
    primary = _StubProvider((_BERN,))
    fallback = _StubProvider((_BERN,))
    hybrid = HybridGeocodingProvider(primary, fallback)

    assert await hybrid.search("bern") == (_BERN,)


@pytest.mark.asyncio
async def test_hybrid_returns_empty_when_both_are_empty() -> None:
    primary = _StubProvider(())
    fallback = _StubProvider(())
    hybrid = HybridGeocodingProvider(primary, fallback)

    assert await hybrid.search("nowhere") == ()
