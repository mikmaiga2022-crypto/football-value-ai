"""Dépendances FastAPI : session, verrouillage, utilisateur courant, permissions."""

from __future__ import annotations

from collections.abc import AsyncIterator, Callable
from typing import Annotated

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.errors import ApiError
from app.core.security import InvalidTokenError, decode_token, has_permission
from app.core.time import server_time
from app.db.models import User
from app.db.session import get_session
from app.schemas.common import Meta
from app.services.lockout import InMemoryLockout, LockoutStore

bearer = HTTPBearer(auto_error=False, description="Jeton d'accès Bearer (15 min)")


async def db_session() -> AsyncIterator[AsyncSession]:
    async for session in get_session():
        yield session


DbSession = Annotated[AsyncSession, Depends(db_session)]


def get_lockout(request: Request) -> LockoutStore:
    store = getattr(request.app.state, "lockout", None)
    if store is None:  # repli sûr si le cycle de vie n'a pas initialisé l'état
        store = InMemoryLockout()
        request.app.state.lockout = store
    return store


Lockout = Annotated[LockoutStore, Depends(get_lockout)]


async def get_current_user(
    request: Request,
    session: DbSession,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)] = None,
) -> User:
    if credentials is None or not credentials.credentials:
        raise ApiError(401, "UNAUTHENTICATED", "Authentification requise.")

    try:
        payload = decode_token(credentials.credentials, expected_type="access")
    except InvalidTokenError as exc:
        code = "TOKEN_EXPIRED" if str(exc) == "TOKEN_EXPIRED" else "UNAUTHENTICATED"
        raise ApiError(401, code, "Jeton d'accès invalide ou expiré.") from exc

    user = await session.get(User, payload.get("sub"))
    if user is None or not user.is_active:
        raise ApiError(401, "UNAUTHENTICATED", "Compte indisponible.")
    if payload.get("role") != user.role:
        # Un changement de rôle invalide les jetons émis avant : pas d'escalade silencieuse.
        raise ApiError(401, "TOKEN_EXPIRED", "Vos droits ont changé. Reconnectez-vous.")
    request.state.user_id = user.id
    return user


CurrentUser = Annotated[User, Depends(get_current_user)]


def require_permission(permission: str) -> Callable[[User], User]:
    async def _guard(user: CurrentUser) -> User:
        if not has_permission(user.role, permission):
            raise ApiError(403, "FORBIDDEN", "Permission insuffisante.", {"required": permission})
        return user

    return _guard


def meta(
    *,
    degraded: bool = False,
    degraded_reason: str | None = None,
    freshness_seconds: int | None = None,
) -> Meta:
    return Meta(
        server_time=server_time(),
        api_version=settings.api_version,
        degraded=degraded,
        degraded_reason=degraded_reason,
        freshness_seconds=freshness_seconds,
    )
