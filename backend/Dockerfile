FROM python:3.12-slim AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY pyproject.toml ./
# Runtime image: only runtime deps, no `[dev]` extras (pytest, ruff, etc.)
RUN pip install --upgrade pip && pip install -e .

COPY app ./app

EXPOSE 8000

# Production: single uvicorn worker for the free-tier Fly VM. Bump to
# multiple workers or gunicorn when the plan grows.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
