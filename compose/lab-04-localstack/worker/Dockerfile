# ── Stage 1: dependency builder ───────────────────────────────────────────────
FROM python:3.12-slim AS builder

WORKDIR /build

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Stage 2: runtime image ────────────────────────────────────────────────────
FROM python:3.12-slim

WORKDIR /app

# Non-root user — same pattern as the api service
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser

COPY --from=builder /install /usr/local
COPY main.py .

RUN chown -R appuser:appgroup /app
USER appuser

# No EXPOSE: the worker is a pull consumer — it initiates outbound SQS calls,
# it never receives inbound connections.
CMD ["python", "-u", "main.py"]