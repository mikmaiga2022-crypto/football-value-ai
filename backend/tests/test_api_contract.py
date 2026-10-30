"""Contrat HTTP : enveloppes, erreurs, en-têtes, pagination, quota."""

from __future__ import annotations

from httpx import AsyncClient

from app.db.models import Competition
from app.db.session import get_sessionmaker
from app.services.quota import QuotaExceeded, QuotaService


async def test_health_envelope(client: AsyncClient) -> None:
    response = await client.get("/v1/health")
    assert response.status_code == 200
    body = response.json()
    assert body["data"]["status"] == "ok"
    assert body["data"]["database"] == "ok"
    assert "server_time" in body["meta"]
    assert response.headers["X-API-Version"]
    assert response.headers["X-Request-ID"].startswith("req_")


async def test_request_id_is_echoed(client: AsyncClient) -> None:
    response = await client.get("/v1/health", headers={"X-Request-ID": "req_test_001"})
    assert response.headers["X-Request-ID"] == "req_test_001"


async def test_not_found_uses_error_envelope(client: AsyncClient) -> None:
    response = await client.get("/v1/inconnu")
    assert response.status_code == 404
    error = response.json()["error"]
    assert error["code"] == "NOT_FOUND"
    assert error["request_id"].startswith("req_")


async def test_validation_error_is_400(client: AsyncClient) -> None:
    response = await client.post("/v1/auth/register", json={"email": "pas-un-email"})
    assert response.status_code == 400
    error = response.json()["error"]
    assert error["code"] == "VALIDATION_ERROR"
    assert error["details"]["fields"]


async def test_meta_endpoints(client: AsyncClient) -> None:
    config = await client.get("/v1/meta/config")
    assert config.status_code == 200
    assert config.json()["data"]["data_mode"] == "zero_budget"

    disclaimer = await client.get("/v1/meta/disclaimer")
    assert disclaimer.status_code == 200
    assert "aucun gain n'est garanti" in disclaimer.json()["data"]["text"].lower()


async def _seed_competitions() -> None:
    async with get_sessionmaker()() as session:
        session.add_all(
            [
                Competition(code="EPL", name="Premier League", tier=1, demand_score=100),
                Competition(code="L1", name="Ligue 1", tier=1, demand_score=95),
                Competition(code="CAN", name="CAN", tier=1, demand_score=90),
                Competition(code="LIGA", name="La Liga", tier=1, demand_score=80),
            ]
        )
        await session.commit()


async def test_competitions_pagination(client: AsyncClient, auth_tokens: dict) -> None:
    await _seed_competitions()
    headers = {"Authorization": f"Bearer {auth_tokens['access_token']}"}

    first = await client.get("/v1/competitions?limit=2", headers=headers)
    assert first.status_code == 200
    body = first.json()
    assert len(body["data"]) == 2
    assert body["pagination"]["has_more"] is True
    cursor = body["pagination"]["next_cursor"]

    second = await client.get(f"/v1/competitions?limit=2&cursor={cursor}", headers=headers)
    assert second.status_code == 200
    assert len(second.json()["data"]) == 2
    assert second.json()["pagination"]["has_more"] is False


async def test_invalid_cursor(client: AsyncClient, auth_tokens: dict) -> None:
    headers = {"Authorization": f"Bearer {auth_tokens['access_token']}"}
    response = await client.get("/v1/competitions?cursor=nawak", headers=headers)
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "INVALID_CURSOR"


async def test_competition_detail_404(client: AsyncClient, auth_tokens: dict) -> None:
    headers = {"Authorization": f"Bearer {auth_tokens['access_token']}"}
    response = await client.get("/v1/competitions/XYZ", headers=headers)
    assert response.status_code == 404


async def test_coverage_endpoint(client: AsyncClient, auth_tokens: dict) -> None:
    await _seed_competitions()
    headers = {"Authorization": f"Bearer {auth_tokens['access_token']}"}
    response = await client.get("/v1/system/coverage", headers=headers)
    assert response.status_code == 200
    data = response.json()["data"]
    assert [entry["code"] for entry in data["served"]] == ["EPL", "L1", "CAN"]
    assert data["monthly_credits"] == 270
    assert data["quota"]["remaining"] == 270
    assert response.json()["meta"]["degraded"] is False


async def test_quota_hard_stop(app) -> None:
    async with get_sessionmaker()() as session:
        service = QuotaService(session)
        await service.spend(200)
        await session.commit()

    async with get_sessionmaker()() as session:
        service = QuotaService(session)
        status = await service.status()
        assert status.used_month == 200
        assert status.remaining == 70

        with __import__("pytest").raises(QuotaExceeded):
            await service.spend(100)
        await session.rollback()

    async with get_sessionmaker()() as session:
        service = QuotaService(session)
        status = await service.spend(70)
        await session.commit()
        assert status.exhausted is True
        assert status.degraded_reason
