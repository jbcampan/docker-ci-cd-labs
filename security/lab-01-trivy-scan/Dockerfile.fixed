# =============================================================================
# DOCKERFILE — FIXED  (Lab 01 · Phase B)
# =============================================================================
# Base image : python:3.13-slim  (Debian Bookworm, actively maintained)
# Purpose    : validate that the pipeline turns green after base image update.
#
# Expected scan result : few or zero CRITICAL CVEs
# Pipeline behaviour   : scan passes → HIGH warning step runs → push unlocked
#
# ── To activate: ─────────────────────────────────────────────────────────────
#   cp Dockerfile.fixed Dockerfile
#   git add Dockerfile
#   git commit -m "fix(security): update base image to python:3.13-slim"
# =============================================================================

FROM python:3.13-slim

WORKDIR /app

COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ .

EXPOSE 8080

CMD ["python", "main.py"]