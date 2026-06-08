# ── Stage 1: dependency builder ───────────────────────────────────────────────
FROM python:3.12-slim AS builder

WORKDIR /build

# Install dependencies into an isolated prefix so we can COPY only the wheels.
# This keeps the final image smaller and leverages Docker layer caching:
# requirements.txt rarely changes → the pip install layer is cached.
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Stage 2: runtime image ────────────────────────────────────────────────────
FROM python:3.12-slim

WORKDIR /app

# Non-root user for security — matches best practices from Lab 03.
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser

# Copy installed packages from the builder stage
COPY --from=builder /install /usr/local

# Copy application source
COPY main.py .

# The appuser owns the workdir so uvicorn can write temp files if needed
RUN chown -R appuser:appgroup /app
USER appuser

EXPOSE 8000

# --no-access-log keeps stdout clean in dev; remove for production debugging
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--no-access-log"]