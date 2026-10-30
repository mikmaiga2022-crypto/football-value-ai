# FOOTBALL VALUE AI — image API (Phase 2)
#
# Aucune clé fournisseur n'est embarquée : elles seront injectées uniquement
# dans les workers en Phase 3 (docs/02 §9). L'image ne contient pas .env.

FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# Utilisateur non privilégié : l'API n'écrit rien sur le disque.
RUN addgroup --system app && adduser --system --ingroup app app

COPY pyproject.toml ./
COPY alembic.ini ./
COPY alembic ./alembic
COPY app ./app

RUN pip install --upgrade pip && pip install .

USER app

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD ["python", "-c", "import sys, urllib.request; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8000/v1/health', timeout=3).status == 200 else 1)"]

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--proxy-headers"]
