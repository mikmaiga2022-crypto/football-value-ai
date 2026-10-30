"""Schémas d'authentification et de profil."""

from __future__ import annotations

from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field, field_validator

from app.core.config import settings


class DeviceIn(BaseModel):
    label: str | None = Field(default=None, max_length=80)
    platform: str | None = Field(default=None, max_length=16)
    app_version: str | None = Field(default=None, max_length=24)


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=settings.password_min_length, max_length=128)
    display_name: str | None = Field(default=None, max_length=60)
    timezone: str = Field(default="Africa/Ouagadougou", max_length=64)
    locale: str = Field(default="fr", pattern="^(fr|en)$")

    @field_validator("display_name")
    @classmethod
    def _strip_name(cls, value: str | None) -> str | None:
        if value is None:
            return None
        cleaned = value.strip()
        return cleaned or None


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=128)
    device: DeviceIn | None = None


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=20, max_length=4096)
    device: DeviceIn | None = None


class LogoutRequest(BaseModel):
    refresh_token: str = Field(min_length=20, max_length=4096)


class UserPublic(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    email: EmailStr
    display_name: str | None
    locale: str
    timezone: str
    role: str
    permissions: list[str] = Field(default_factory=list)
    created_at: datetime


class ProfilePatch(BaseModel):
    display_name: str | None = Field(default=None, max_length=60)
    timezone: str | None = Field(default=None, max_length=64)
    locale: str | None = Field(default=None, pattern="^(fr|en)$")


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"  # noqa: S105 (nom de schéma, pas un secret)
    expires_in: int
    user: UserPublic
