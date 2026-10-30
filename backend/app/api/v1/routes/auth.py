"""Inscription, connexion, rotation, déconnexion, profil."""

from __future__ import annotations

from fastapi import APIRouter, Request, status

from app.api.deps import CurrentUser, DbSession, Lockout, meta
from app.core.config import settings
from app.schemas.auth import (
    LoginRequest,
    LogoutRequest,
    ProfilePatch,
    RefreshRequest,
    RegisterRequest,
    TokenResponse,
    UserPublic,
)
from app.schemas.common import Envelope
from app.services import auth as auth_service

router = APIRouter(tags=["auth"])


def _user_public(user, permissions: list[str]) -> UserPublic:
    return UserPublic(
        id=user.id,
        email=user.email,
        display_name=user.display_name,
        locale=user.locale,
        timezone=user.timezone,
        role=user.role,
        permissions=permissions,
        created_at=user.created_at,
    )


@router.post(
    "/auth/register",
    response_model=Envelope[TokenResponse],
    status_code=status.HTTP_201_CREATED,
    summary="Créer un compte et ouvrir une session",
)
async def register(
    payload: RegisterRequest, session: DbSession, request: Request
) -> Envelope[TokenResponse]:
    user = await auth_service.register_user(
        session,
        email=payload.email,
        password=payload.password,
        display_name=payload.display_name,
        locale=payload.locale,
        timezone=payload.timezone,
    )
    pair, _ = await auth_service.issue_tokens(
        session,
        user=user,
        device=auth_service.DeviceInfo(label="premier appareil", platform="android"),
    )
    await session.commit()
    request.state.user_id = user.id
    data = TokenResponse(
        access_token=pair.access_token,
        refresh_token=pair.refresh_token,
        expires_in=settings.access_token_ttl_seconds,
        user=_user_public(user, auth_service.public_permissions(user)),
    )
    return Envelope(data=data, meta=meta())


@router.post("/auth/login", response_model=Envelope[TokenResponse], summary="Se connecter")
async def login(
    payload: LoginRequest, session: DbSession, lockout: Lockout, request: Request
) -> Envelope[TokenResponse]:
    user = await auth_service.authenticate(
        session, email=payload.email, password=payload.password, lockout=lockout
    )
    device = (
        auth_service.DeviceInfo(
            label=payload.device.label,
            platform=payload.device.platform,
            app_version=payload.device.app_version,
        )
        if payload.device
        else None
    )
    pair, _ = await auth_service.issue_tokens(session, user=user, device=device)
    await session.commit()
    request.state.user_id = user.id
    data = TokenResponse(
        access_token=pair.access_token,
        refresh_token=pair.refresh_token,
        expires_in=settings.access_token_ttl_seconds,
        user=_user_public(user, auth_service.public_permissions(user)),
    )
    return Envelope(data=data, meta=meta())


@router.post("/auth/refresh", response_model=Envelope[TokenResponse], summary="Rotation des jetons")
async def refresh(payload: RefreshRequest, session: DbSession) -> Envelope[TokenResponse]:
    device = (
        auth_service.DeviceInfo(
            label=payload.device.label,
            platform=payload.device.platform,
            app_version=payload.device.app_version,
        )
        if payload.device
        else None
    )
    pair, _, user = await auth_service.rotate_tokens(
        session, refresh_token=payload.refresh_token, device=device
    )
    await session.commit()
    data = TokenResponse(
        access_token=pair.access_token,
        refresh_token=pair.refresh_token,
        expires_in=settings.access_token_ttl_seconds,
        user=_user_public(user, auth_service.public_permissions(user)),
    )
    return Envelope(data=data, meta=meta())


@router.post(
    "/auth/logout",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Révoquer la session courante",
)
async def logout(payload: LogoutRequest, session: DbSession) -> None:
    await auth_service.revoke_refresh_token(session, refresh_token=payload.refresh_token)
    await session.commit()


@router.get("/me", response_model=Envelope[UserPublic], summary="Profil courant")
async def me(user: CurrentUser) -> Envelope[UserPublic]:
    return Envelope(data=_user_public(user, auth_service.public_permissions(user)), meta=meta())


@router.patch("/me", response_model=Envelope[UserPublic], summary="Mettre à jour le profil")
async def patch_me(
    payload: ProfilePatch, user: CurrentUser, session: DbSession
) -> Envelope[UserPublic]:
    if payload.display_name is not None:
        user.display_name = payload.display_name.strip() or None
    if payload.timezone is not None:
        user.timezone = payload.timezone
    if payload.locale is not None:
        user.locale = payload.locale
    await session.flush()
    await session.commit()
    return Envelope(data=_user_public(user, auth_service.public_permissions(user)), meta=meta())
