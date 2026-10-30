"""Authentification : inscription, connexion, rotation des jetons, révocation.

Le service est volontairement indépendant de FastAPI : il reçoit une `AsyncSession` et des
valeurs, il lève des `ApiError` du domaine HTTP (mapping direct vers l'enveloppe d'erreur).
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime

from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.errors import ApiError
from app.core.ids import new_id
from app.core.security import (
    InvalidTokenError,
    TokenPair,
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    needs_rehash,
    password_policy_error,
    permissions_for,
    token_fingerprint,
    verify_password,
)
from app.core.time import add_days, add_seconds, as_utc, utcnow
from app.db.models import RefreshToken, User
from app.services.lockout import LockoutStore


@dataclass(frozen=True)
class DeviceInfo:
    label: str | None = None
    platform: str | None = None
    app_version: str | None = None


def _normalize_email(email: str) -> str:
    return email.strip().lower()


async def get_user_by_email(session: AsyncSession, email: str) -> User | None:
    result = await session.execute(select(User).where(User.email == _normalize_email(email)))
    return result.scalar_one_or_none()


async def get_user_by_id(session: AsyncSession, user_id: str) -> User | None:
    return await session.get(User, user_id)


async def register_user(
    session: AsyncSession,
    *,
    email: str,
    password: str,
    display_name: str | None = None,
    locale: str = "fr",
    timezone: str = "Africa/Ouagadougou",
) -> User:
    policy_error = password_policy_error(password)
    if policy_error:
        raise ApiError(400, "VALIDATION_ERROR", policy_error, {"field": "password"})

    normalized = _normalize_email(email)
    if await get_user_by_email(session, normalized):
        raise ApiError(409, "CONFLICT", "Un compte existe déjà avec cette adresse.")

    user = User(
        id=new_id("usr"),
        email=normalized,
        password_hash=hash_password(password),
        display_name=(display_name or "").strip() or None,
        locale=locale,
        timezone=timezone,
        role="user",
        password_changed_at=utcnow(),
    )
    session.add(user)
    try:
        await session.flush()
    except IntegrityError as exc:
        await session.rollback()
        raise ApiError(409, "CONFLICT", "Un compte existe déjà avec cette adresse.") from exc
    return user


async def authenticate(
    session: AsyncSession,
    *,
    email: str,
    password: str,
    lockout: LockoutStore,
) -> User:
    normalized = _normalize_email(email)
    key = f"login:{normalized}"

    remaining = await lockout.seconds_remaining(key)
    if remaining > 0:
        raise ApiError(
            429,
            "RATE_LIMITED",
            "Trop de tentatives. Réessayez plus tard.",
            {"retry_after_seconds": remaining},
            headers={"Retry-After": str(remaining)},
        )

    user = await get_user_by_email(session, normalized)
    if user is None or not verify_password(password, user.password_hash):
        locked_for = await lockout.register_failure(key)
        details = {"attempts_left": max(0, settings.max_login_attempts - 1)}
        if locked_for:
            details = {"retry_after_seconds": locked_for}
        raise ApiError(
            401,
            "UNAUTHENTICATED",
            "Adresse ou mot de passe incorrect.",
            details,
        )

    if not user.is_active:
        raise ApiError(403, "FORBIDDEN", "Ce compte est désactivé.")

    await lockout.reset(key)
    if needs_rehash(user.password_hash):
        user.password_hash = hash_password(password)

    user.failed_logins = 0
    user.locked_until = None
    user.last_login_at = utcnow()
    await session.flush()
    return user


async def issue_tokens(
    session: AsyncSession,
    *,
    user: User,
    device: DeviceInfo | None = None,
    family_id: str | None = None,
) -> tuple[TokenPair, RefreshToken]:
    now = utcnow()
    family = family_id or new_id("fam")
    access = create_access_token(subject=user.id, role=user.role, session_id=family)
    refresh = create_refresh_token(subject=user.id, session_id=family, family_id=family)

    row = RefreshToken(
        id=new_id("rft"),
        user_id=user.id,
        family_id=family,
        token_hash=token_fingerprint(refresh),
        device_label=(device.label if device else None),
        platform=(device.platform if device else None),
        app_version=(device.app_version if device else None),
        issued_at=now,
        expires_at=add_days(now, settings.refresh_token_ttl_days),
    )
    session.add(row)
    await session.flush()

    pair = TokenPair(
        access_token=access,
        refresh_token=refresh,
        access_expires_at=add_seconds(now, settings.access_token_ttl_seconds),
        refresh_expires_at=row.expires_at,
    )
    return pair, row


async def rotate_tokens(
    session: AsyncSession,
    *,
    refresh_token: str,
    device: DeviceInfo | None = None,
) -> tuple[TokenPair, RefreshToken, User]:
    try:
        payload = decode_token(refresh_token, expected_type="refresh")
    except InvalidTokenError as exc:
        raise ApiError(401, "UNAUTHENTICATED", "Jeton de rafraîchissement invalide.") from exc

    fingerprint = token_fingerprint(refresh_token)
    result = await session.execute(
        select(RefreshToken).where(RefreshToken.token_hash == fingerprint)
    )
    row = result.scalar_one_or_none()
    if row is None:
        raise ApiError(401, "UNAUTHENTICATED", "Session inconnue.")

    if row.revoked_at is not None or row.used_at is not None:
        # Réutilisation d'un jeton déjà consommé : on révoque toute la famille (vol probable).
        # Le commit est indispensable : sans lui, l'exception annulerait la révocation.
        await _revoke_family(session, user_id=row.user_id, family_id=row.family_id, reason="reuse")
        await session.commit()
        raise ApiError(401, "UNAUTHENTICATED", "Session révoquée. Reconnectez-vous.")

    if as_utc(row.expires_at) <= utcnow():
        row.revoked_at = utcnow()
        row.revoked_reason = "expired"
        await session.commit()
        raise ApiError(401, "UNAUTHENTICATED", "Session expirée. Reconnectez-vous.")

    if payload.get("sub") != row.user_id:
        await _revoke_family(
            session, user_id=row.user_id, family_id=row.family_id, reason="mismatch"
        )
        await session.commit()
        raise ApiError(401, "UNAUTHENTICATED", "Jeton incohérent.")

    user = await session.get(User, row.user_id)
    if user is None or not user.is_active:
        raise ApiError(401, "UNAUTHENTICATED", "Compte indisponible.")

    pair, new_row = await issue_tokens(session, user=user, device=device, family_id=row.family_id)
    row.used_at = utcnow()
    row.revoked_at = utcnow()
    row.revoked_reason = "rotated"
    row.replaced_by_id = new_row.id
    await session.flush()
    return pair, new_row, user


async def revoke_refresh_token(session: AsyncSession, *, refresh_token: str) -> None:
    fingerprint = token_fingerprint(refresh_token)
    result = await session.execute(
        select(RefreshToken).where(RefreshToken.token_hash == fingerprint)
    )
    row = result.scalar_one_or_none()
    if row is None or row.revoked_at is not None:
        return
    row.revoked_at = utcnow()
    row.revoked_reason = "logout"
    await session.flush()


async def _revoke_family(
    session: AsyncSession, *, user_id: str, family_id: str, reason: str
) -> None:
    result = await session.execute(
        select(RefreshToken).where(
            RefreshToken.user_id == user_id, RefreshToken.family_id == family_id
        )
    )
    now = utcnow()
    for token in result.scalars():
        if token.revoked_at is None:
            token.revoked_at = now
            token.revoked_reason = reason
    await session.flush()


def public_permissions(user: User) -> list[str]:
    return permissions_for(user.role)


def session_expiry(user: User) -> datetime:  # pragma: no cover - utilitaire d'affichage
    return add_days(utcnow(), settings.refresh_token_ttl_days)
