# =============================================================================
# DOCKERFILE — INTENTIONALLY VULNERABLE  (Lab 01 · Phase A)
# =============================================================================
# Base image : python:3.8-slim-buster  (Debian Buster, EOL June 2022)
# Purpose    : trigger Trivy CRITICAL findings and observe pipeline blocking.
#
# Expected scan result : multiple CRITICAL CVEs in the OS layer
#                        (glibc, zlib, openssl, …)
# Pipeline behaviour   : job fails at step "Trivy scan — block on CRITICAL CVEs"
#                        SARIF report is still uploaded (if: always())
#
# ── To move to Phase B (green pipeline): ─────────────────────────────────────
#   cp Dockerfile.fixed Dockerfile
#   git add Dockerfile
#   git commit -m "fix(security): update base image to python:3.13-slim"
# =============================================================================

FROM python:3.8-slim-buster

WORKDIR /app

COPY app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ .

EXPOSE 8080

CMD ["python", "main.py"]