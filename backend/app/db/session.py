"""Engine et sessions asynchrones.

En production : PostgreSQL 16 via asyncpg (pool borné).
En test : SQLite en mémoire via aiosqlite (aucune dépendance externe) — les modèles restent
portables ; la validation PostgreSQL réelle est un prérequis de la Phase 3.
"""

from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from app.core.config import settings
from app.db.base import Base

_engine: AsyncEngine | None = None
_sessionmaker: async_sessionmaker[AsyncSession] | None = None


def _engine_kwargs(url: str) -> dict:
    if url.startswith("sqlite"):
        # SQLite : pas d'options de pool serveur ; en mémoire, une seule connexion partagée.
        kwargs: dict = {"connect_args": {"check_same_thread": False}}
        if ":memory:" in url:
            from sqlalchemy.pool import StaticPool

            kwargs["poolclass"] = StaticPool
        return kwargs
    return {
        "pool_size": settings.db_pool_size,
        "max_overflow": settings.db_max_overflow,
        "pool_pre_ping": True,
        "pool_recycle": 1800,
    }


def create_engine(url: str | None = None) -> AsyncEngine:
    target = url or settings.database_url
    return create_async_engine(target, echo=settings.db_echo, **_engine_kwargs(target))


def init_engine(url: str | None = None) -> AsyncEngine:
    global _engine, _sessionmaker
    _engine = create_engine(url)
    _sessionmaker = async_sessionmaker(_engine, expire_on_commit=False, class_=AsyncSession)
    return _engine


def get_engine() -> AsyncEngine:
    if _engine is None:
        init_engine()
    assert _engine is not None
    return _engine


def get_sessionmaker() -> async_sessionmaker[AsyncSession]:
    if _sessionmaker is None:
        init_engine()
    assert _sessionmaker is not None
    return _sessionmaker


async def get_session() -> AsyncIterator[AsyncSession]:
    """Dépendance FastAPI : une session par requête, rollback automatique en cas d'erreur."""
    async with get_sessionmaker()() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise


@asynccontextmanager
async def session_scope() -> AsyncIterator[AsyncSession]:
    async with get_sessionmaker()() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise


async def create_all() -> None:
    """Réservé aux tests et au démarrage local (migrations Alembic en staging/prod)."""
    engine = get_engine()
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


async def dispose_engine() -> None:
    global _engine, _sessionmaker
    if _engine is not None:
        await _engine.dispose()
    _engine = None
    _sessionmaker = None
