"""Verrouillage progressif après échecs de connexion (docs/04 §2).

Deux implémentations : mémoire (dev/tests) et Redis (production). L'interface est identique,
ce qui évite de dépendre de Redis dans les tests unitaires.
"""

from __future__ import annotations

import time
from typing import Protocol

from app.core.config import settings

_KEY_PREFIX = "fva:lockout:"


class LockoutStore(Protocol):
    async def seconds_remaining(self, key: str) -> int: ...
    async def register_failure(self, key: str) -> int: ...
    async def reset(self, key: str) -> None: ...


class InMemoryLockout:
    def __init__(self) -> None:
        self._failures: dict[str, int] = {}
        self._until: dict[str, float] = {}

    async def seconds_remaining(self, key: str) -> int:
        until = self._until.get(key, 0.0)
        remaining = int(until - time.time())
        return max(0, remaining)

    async def register_failure(self, key: str) -> int:
        failures = self._failures.get(key, 0) + 1
        self._failures[key] = failures
        if failures >= settings.max_login_attempts:
            schedule = settings.lockout_seconds
            step = min(failures - settings.max_login_attempts, len(schedule) - 1)
            seconds = schedule[step]
            self._until[key] = time.time() + seconds
            return seconds
        return 0

    async def reset(self, key: str) -> None:
        self._failures.pop(key, None)
        self._until.pop(key, None)


class RedisLockout:
    """Compteur TTL : la clé expire exactement à la fin du verrouillage."""

    def __init__(self, client) -> None:  # client: redis.asyncio.Redis
        self.client = client

    async def seconds_remaining(self, key: str) -> int:
        ttl = await self.client.ttl(_KEY_PREFIX + "until:" + key)
        return max(0, int(ttl or 0))

    async def register_failure(self, key: str) -> int:
        full_key = _KEY_PREFIX + key
        failures = await self.client.incr(full_key)
        await self.client.expire(full_key, 24 * 3600)
        if failures < settings.max_login_attempts:
            return 0
        schedule = settings.lockout_seconds
        step = min(int(failures) - settings.max_login_attempts, len(schedule) - 1)
        seconds = schedule[step]
        await self.client.set(_KEY_PREFIX + "until:" + key, "1", ex=seconds)
        return seconds

    async def reset(self, key: str) -> None:
        await self.client.delete(_KEY_PREFIX + key, _KEY_PREFIX + "until:" + key)
