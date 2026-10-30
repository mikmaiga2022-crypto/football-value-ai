"""Application Celery (Phase 2 : câblage uniquement, aucune tâche de collecte active).

Les tâches de collecte, d'inférence et de notification arrivent en phases 3 à 6. Ici, seule
la topologie est posée : un worker, un beat, des files séparées par criticité.
"""

from __future__ import annotations

from celery import Celery
from celery.schedules import crontab

from app.core.config import settings

celery_app = Celery(
    "football_value_ai",
    broker=settings.celery_broker_url,
    backend=settings.celery_result_backend,
    include=["app.jobs.tasks"],
)

celery_app.conf.update(
    task_serializer="json",
    result_serializer="json",
    accept_content=["json"],
    timezone="UTC",
    enable_utc=True,
    task_acks_late=True,
    task_reject_on_worker_lost=True,
    worker_prefetch_multiplier=1,
    task_default_queue="default",
    task_routes={
        "app.jobs.tasks.ping": {"queue": "default"},
    },
    # Planification prévue (désactivée tant que la Phase 3 n'est pas livrée).
    beat_schedule={},
)

if settings.environment == "dev":  # pragma: no cover - confort local
    celery_app.conf.beat_schedule = {
        "coverage-plan-daily": {
            "task": "app.jobs.tasks.recompute_coverage_plan",
            "schedule": crontab(hour=4, minute=10),
        }
    }
