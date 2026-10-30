"""Authentification : inscription, connexion, rotation, détection de réutilisation."""

from __future__ import annotations

from httpx import AsyncClient


async def test_register_returns_tokens_and_permissions(
    client: AsyncClient, user_payload: dict
) -> None:
    response = await client.post("/v1/auth/register", json=user_payload)
    assert response.status_code == 201
    body = response.json()
    assert body["data"]["token_type"] == "Bearer"
    assert body["data"]["user"]["email"] == "testeur@example.com"
    assert "value.read" in body["data"]["user"]["permissions"]
    assert body["meta"]["api_version"]
    assert body["meta"]["server_time"].endswith("Z")


async def test_duplicate_email_conflict(client: AsyncClient, user_payload: dict) -> None:
    assert (await client.post("/v1/auth/register", json=user_payload)).status_code == 201
    second = await client.post("/v1/auth/register", json=user_payload)
    assert second.status_code == 409
    assert second.json()["error"]["code"] == "CONFLICT"


async def test_weak_password_rejected(client: AsyncClient) -> None:
    response = await client.post(
        "/v1/auth/register",
        json={"email": "faible@example.com", "password": "court"},
    )
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "VALIDATION_ERROR"


async def test_me_requires_authentication(client: AsyncClient) -> None:
    response = await client.get("/v1/me")
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "UNAUTHENTICATED"


async def test_login_and_me(client: AsyncClient, auth_tokens: dict) -> None:
    login = await client.post(
        "/v1/auth/login",
        json={
            "email": "testeur@example.com",
            "password": "MotDePasse2026!",
            "device": {"label": "Pixel 7", "platform": "android", "app_version": "0.1.0"},
        },
    )
    assert login.status_code == 200
    access = login.json()["data"]["access_token"]

    me = await client.get("/v1/me", headers={"Authorization": f"Bearer {access}"})
    assert me.status_code == 200
    assert me.json()["data"]["timezone"] == "Africa/Ouagadougou"


async def test_wrong_password_then_lockout(client: AsyncClient, user_payload: dict) -> None:
    await client.post("/v1/auth/register", json=user_payload)
    for _ in range(5):
        response = await client.post(
            "/v1/auth/login",
            json={"email": user_payload["email"], "password": "MauvaisMotDePasse1"},
        )
        assert response.status_code == 401

    blocked = await client.post(
        "/v1/auth/login",
        json={"email": user_payload["email"], "password": "MauvaisMotDePasse1"},
    )
    assert blocked.status_code == 429
    assert blocked.json()["error"]["code"] == "RATE_LIMITED"
    assert "Retry-After" in blocked.headers


async def test_refresh_rotation(client: AsyncClient, auth_tokens: dict) -> None:
    refreshed = await client.post(
        "/v1/auth/refresh", json={"refresh_token": auth_tokens["refresh_token"]}
    )
    assert refreshed.status_code == 200
    new_tokens = refreshed.json()["data"]
    assert new_tokens["refresh_token"] != auth_tokens["refresh_token"]

    # L'ancien jeton est consommé : le réutiliser doit être détecté comme un vol.
    replay = await client.post(
        "/v1/auth/refresh", json={"refresh_token": auth_tokens["refresh_token"]}
    )
    assert replay.status_code == 401
    assert replay.json()["error"]["code"] == "UNAUTHENTICATED"

    # Et toute la famille est révoquée, y compris le jeton fraîchement émis.
    after = await client.post(
        "/v1/auth/refresh", json={"refresh_token": new_tokens["refresh_token"]}
    )
    assert after.status_code == 401


async def test_logout_revokes_session(client: AsyncClient, auth_tokens: dict) -> None:
    logout = await client.post(
        "/v1/auth/logout", json={"refresh_token": auth_tokens["refresh_token"]}
    )
    assert logout.status_code == 204
    refresh = await client.post(
        "/v1/auth/refresh", json={"refresh_token": auth_tokens["refresh_token"]}
    )
    assert refresh.status_code == 401


async def test_patch_profile(client: AsyncClient, auth_tokens: dict) -> None:
    access = auth_tokens["access_token"]
    response = await client.patch(
        "/v1/me",
        json={"display_name": "Nouveau nom", "locale": "en"},
        headers={"Authorization": f"Bearer {access}"},
    )
    assert response.status_code == 200
    assert response.json()["data"]["display_name"] == "Nouveau nom"
    assert response.json()["data"]["locale"] == "en"
