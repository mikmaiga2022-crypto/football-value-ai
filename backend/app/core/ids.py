"""Identifiants opaques (ULID) — jamais d'entier incrémental exposé (docs/04 §1)."""

from __future__ import annotations

import os
import time

_ALPHABET = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"  # Crockford base32
_TIME_LEN = 10
_RANDOM_LEN = 16


def _encode(number: int, length: int) -> str:
    chars = []
    for _ in range(length):
        number, rem = divmod(number, 32)
        chars.append(_ALPHABET[rem])
    return "".join(reversed(chars))


def ulid() -> str:
    """ULID 26 caractères, trié par le temps (monotonicité non garantie en multi-process)."""
    millis = int(time.time() * 1000)
    randomness = int.from_bytes(os.urandom(10), "big")
    return _encode(millis, _TIME_LEN) + _encode(randomness, _RANDOM_LEN)


def new_id(prefix: str) -> str:
    """Identifiant préfixé conforme au contrat : `usr_01J9…`, `req_01J9…`."""
    return f"{prefix}_{ulid()}"
