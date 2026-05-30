# ── Stage 1: Builder ──────────────────────────────────────────
# Contains all build and test tools
FROM python:3.11-slim AS builder

WORKDIR /app

COPY app/requirements.txt .

# Install into an isolated directory (not into system Python)
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# ── Stage 2: Runner ───────────────────────────────────────────
# Final image — contains only the strict minimum needed to run
FROM python:3.11-slim AS runner

WORKDIR /app

# Copy ONLY installed dependencies from builder stage
COPY --from=builder /install /usr/local

# Copy application code
COPY app/app.py .

# Non-root user for security purposes
RUN useradd --no-create-home appuser
USER appuser

EXPOSE 5000
CMD ["python", "app.py"]