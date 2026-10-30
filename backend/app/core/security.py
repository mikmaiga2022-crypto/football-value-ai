"""Sécurité : hachage Argon2id, jetons JWT, hachage des refresh tokens, permissions.

Règles (docs/04 §2) :
- mot de passe ≥ 10 caractères, jamais journalisé ;
- access token 15 min, refresh token 30 jours rotatif ;
- le refresh token est stocké **haché** (SHA-256) : une fuite de base ne permet pas de l'utiliser ;
- la réutilisation d'un refresh token révoqué révoque toute sa famille (détection de vol).
"""

from __future__ import annotations

import hashlib
import secrets
from dataclasses import dataclass
from datetime import datetime
from typing import Literal

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError, VerifyMismatchError

from app.core.config import settings
from app.core.time import utcnow

TokenType = Literal["access", "refresh"]


class InvalidTokenError(Exception):
    """Jeton absent, malformé, expiré ou de mauvais type."""


# Paramètres OWASP 2024 pour Argon2id (19 Mio, t=2, p=1) — ajustables sans casser l'existant :
# le hash stocké porte ses propres paramètres.
_hasher = PasswordHasher(time_cost=2, memory_cost=19456, parallelism=1, hash_len=32, salt_len=16)

#: Permissions par rôle. Le mobile ne fait jamais d'inférence : il lit cette liste.
ROLE_PERMISSIONS: dict[str, frozenset[str]] = {
    "user": frozenset(
        {
            "matches.read",
            "odds.read",
            "predictions.read",
            "value.read",
            "favorites.write",
            "simulation.write",
        }
    ),
    "analyst": frozenset(
        {
            "matches.read",
            "odds.read",
            "predictions.read",
            "value.read",
            "favorites.write",
            "simulation.write",
            "admin.health",
            "admin.odds.write",
            "admin.publish",
        }
    ),
    "admin": frozenset({"*"}),
}


def permissions_for(role: str) -> list[str]:
    return sorted(ROLE_PERMISSIONS.get(role, frozenset()))


def has_permission(role: str, permission: str) -> bool:
    granted = ROLE_PERMISSIONS.get(role, frozenset())
    return "*" in granted or permission in granted


def hash_password(password: str) -> str:
    return _hasher.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return _hasher.verify(password_hash, password)
    except (VerifyMismatchError, VerificationError, InvalidHashError):
        return False


def needs_rehash(password_hash: str) -> bool:
    try:
        return _hasher.check_needs_rehash(password_hash)
    except InvalidHashError:
        return True


@dataclass(frozen=True)
class TokenPair:
    access_token: str
    refresh_token: str
    access_expires_at: datetime
    refresh_expires_at: datetime


def _encode(payload: dict, ttl_seconds: int, token_type: TokenType) -> str:
    now = utcnow()
    body = {
        **payload,
        "typ": token_type,
        "iss": settings.jwt_issuer,
        "iat": int(now.timestamp()),
        "exp": int(now.timestamp()) + ttl_seconds,
    }
    return jwt.encode(body, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def create_access_token(*, subject: str, role: str, session_id: str) -> str:
    return _encode(
        {"sub": subject, "role": role, "sid": session_id},
        settings.access_token_ttl_seconds,
        "access",
    )


def create_refresh_token(*, subject: str, session_id: str, family_id: str) -> str:
    return _encode(
        {"sub": subject, "sid": session_id, "fam": family_id, "jti": secrets.token_urlsafe(16)},
        settings.refresh_token_ttl_days * 24 * 3600,
        "refresh",
    )


def decode_token(token: str, *, expected_type: TokenType) -> dict:
    try:
        payload = jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=[settings.jwt_algorithm],
            issuer=settings.jwt_issuer,
            options={"require": ["exp", "iat", "sub", "typ"]},
        )
    except jwt.ExpiredSignatureError as exc:
        raise InvalidTokenError("TOKEN_EXPIRED") from exc
    except jwt.InvalidTokenError as exc:
        raise InvalidTokenError("INVALID_TOKEN") from exc

    if payload.get("typ") != expected_type:
        raise InvalidTokenError("INVALID_TOKEN")
    return payload


def token_fingerprint(token: str) -> str:
    """Empreinte SHA-256 du refresh token, seule valeur persistée."""
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def password_policy_error(password: str) -> str | None:
    """Retourne un message d'erreur, ou `None` si le mot de passe est acceptable."""
    if len(password) < settings.password_min_length:
        return f"Le mot de passe doit contenir au moins {settings.password_min_length} caractères."
    if password.lower() in {"password12", "motdepasse1", "12345678910", "footballvalue"}:
        return "Ce mot de passe est trop courant."
    if not any(char.isalpha() for char in password) or not any(char.isdigit() for char in password):
        return "Le mot de passe doit contenir au moins une lettre et un chiffre."
    return None
