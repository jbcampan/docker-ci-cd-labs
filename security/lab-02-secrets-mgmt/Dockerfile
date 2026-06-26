# syntax=docker/dockerfile:1
# ---------------------------------------------------------------------------
# Stage 1 — dependency builder
# ---------------------------------------------------------------------------
FROM python:3.12-slim AS builder

WORKDIR /build

# Install dependencies into an isolated prefix so the final image stays clean.
COPY app/requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ---------------------------------------------------------------------------
# Stage 2 — minimal runtime image
# ---------------------------------------------------------------------------
FROM python:3.12-slim AS runtime

WORKDIR /app

# Copy installed packages from the builder stage.
COPY --from=builder /install /usr/local

# Copy application source.
COPY app/main.py .

# Non-root user for least-privilege execution inside the container.
RUN useradd --create-home --shell /bin/bash appuser
# Drop to non-root.
USER appuser

# APP_SECRET_NAME: name or ARN of the Secrets Manager secret (required at runtime).
# AWS credentials are provided via OIDC / instance role — never baked into the image.
ENV APP_SECRET_NAME=""
ENV AWS_REGION="eu-west-3"

# The container exits after startup to demonstrate the secret-fetch flow.
# In a real service, replace with your long-running process (uvicorn, gunicorn, …).
CMD ["python", "main.py"]
