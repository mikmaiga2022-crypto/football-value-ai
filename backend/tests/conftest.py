"""Fixtures de test : application réelle, base SQLite en mémoire, client ASGI."""

from __future__ import annotations

import os
import sys
from collections.abc import AsyncIterator
from pathlib import Path

import pytest
from httpx import ASGITransport, AsyncClient

os.environ.setdefault("FVA_ENVIRONMENT", "test")
os.environ.setdefault("FVA_JWT_SECRET", "test-secret-0123456789-0123456789-ok")

BACKEND = Path(__file__).resolve().parents[1]
if str(BACKEND) not in sys.path:
    sys.path.insert(0, str(BACKEND))

from app.core.config import get_settings  # noqa: E402
from app.db.session import create_all, dispose_engine, init_engine  # noqa: E402
from app.main import create_app  # noqa: E402
from app.services.lockout import InMemoryLockout  # noqa: E402

get_settings.cache_clear()


@pytest.fixture(scope="session")
def settings():
    return get_settings()


@pytest.fixture
async def app() -> AsyncIterator:
    init_engine("sqlite+aiosqlite:///:memory:")
    await create_all()
    application = create_app()
    # Le cycle de vie n'est pas exécuté par ASGITransport : on câble l'état minimal.
    application.state.lockout = InMemoryLockout()
    yield application
    await dispose_engine()


@pytest.fixture
async def client(app) -> AsyncIterator[AsyncClient]:
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as http:
        yield http


@pytest.fixture
async def user_payload() -> dict:
    return {
        "email": "testeur@example.com",
        "password": "MotDePasse2026!",
        "display_name": "Testeur",
        "timezone": "Africa/Ouagadougou",
        "locale": "fr",
    }


@pytest.fixture
async def auth_tokens(client: AsyncClient, user_payload: dict) -> dict:
    response = await client.post("/v1/auth/register", json=user_payload)
    assert response.status_code == 201, response.text
    return response.json()["data"]
