# syntax=docker/dockerfile:1
# ---------------------------------------------------------------------------
# Stage 1 — dependencies
# ---------------------------------------------------------------------------
FROM python:3.12-slim AS builder

WORKDIR /app

COPY app/requirements.txt .

RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---------------------------------------------------------------------------
# Stage 2 — runtime
# ---------------------------------------------------------------------------
FROM python:3.12-slim AS runner

WORKDIR /app

# Install curl (and cleanup to keep image small)
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /install /usr/local

COPY app/main.py .

RUN adduser --disabled-password --gecos "" appuser
USER appuser

# ECS task definition maps container port 5000 → ALB target group
EXPOSE 5000

# APP_VERSION and ENVIRONMENT are injected at runtime via the ECS task
# definition environment block (set by the GitHub Actions workflow).
ENV APP_VERSION=0.0.0 \
    ENVIRONMENT=production \
    PORT=5000

# Gunicorn with 2 workers — appropriate for 0.25 vCPU Fargate task
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--timeout", "30", "main:app"]