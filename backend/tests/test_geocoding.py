from __future__ import annotations

import pytest

from app.domain import Country
from app.providers import MockGeocodingProvider


@pytest.mark.asyncio
async def test_prefix_matches_rank_first() -> None:
    provider = MockGeocodingProvider()
    results = await provider.search("bar")
    # "Barcelona" (prefix) should come before any mid-string match.
    assert results
    assert results[0].display_name.startswith("Barcelona")


@pytest.mark.asyncio
async def test_search_is_case_insensitive() -> None:
    provider = MockGeocodingProvider()
    lower = await provider.search("paris")
    upper = await provider.search("PARIS")
    assert lower == upper
    assert lower[0].country is Country.FR


@pytest.mark.asyncio
async def test_empty_query_returns_empty_tuple() -> None:
    provider = MockGeocodingProvider()
    assert await provider.search("") == ()
    assert await provider.search("   ") == ()


@pytest.mark.asyncio
async def test_limit_caps_results() -> None:
    provider = MockGeocodingProvider()
    results = await provider.search("a", limit=3)
    assert len(results) <= 3


@pytest.mark.asyncio
async def test_returns_country_for_each_match() -> None:
    provider = MockGeocodingProvider()
    for result in await provider.search("bern"):
        assert result.country is Country.CH
