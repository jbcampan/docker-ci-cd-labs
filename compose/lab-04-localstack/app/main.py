"""
api/main.py — FastAPI producer service.

Exposes three endpoints:
  POST /upload      → upload a text file to S3 + enqueue a processing message
  GET  /files       → list all objects in the S3 bucket
  GET  /health      → liveness probe for Docker healthcheck
"""

import json
import os
import uuid
from datetime import datetime, timezone

import boto3
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel

# ── AWS clients ───────────────────────────────────────────────────────────────
# endpoint_url is read from the environment variable AWS_ENDPOINT_URL.
# boto3 picks it up automatically — no code change needed between local and prod.
# In production, simply unset AWS_ENDPOINT_URL and boto3 hits the real AWS APIs.

S3_BUCKET = os.environ["S3_BUCKET"]
SQS_QUEUE_NAME = os.environ["SQS_QUEUE_NAME"]
AWS_REGION = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")

session = boto3.session.Session()

s3 = session.client("s3")
sqs = session.client("sqs")

app = FastAPI(
    title="Lab04 API",
    description="Producer service: upload files to S3, enqueue SQS messages.",
    version="1.0.0",
)


# ── Helpers ───────────────────────────────────────────────────────────────────

def get_queue_url() -> str:
    """Resolve SQS queue URL from its name (cached lazily)."""
    resp = sqs.get_queue_url(QueueName=SQS_QUEUE_NAME)
    return resp["QueueUrl"]


# ── Schemas ───────────────────────────────────────────────────────────────────

class UploadRequest(BaseModel):
    filename: str
    content: str


# ── Routes ───────────────────────────────────────────────────────────────────

@app.get("/health")
def health() -> dict:
    """Liveness probe used by Docker healthcheck and load balancers."""
    return {"status": "ok", "service": "api"}


@app.post("/upload", status_code=201)
def upload_file(req: UploadRequest) -> dict:
    """
    1. Write `req.content` to S3 under a timestamped key.
    2. Publish a processing message to SQS referencing that key.

    Returns the S3 key and SQS message ID so callers can track progress.
    """
    # Build a unique S3 key to avoid collisions
    ts = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%S")
    uid = uuid.uuid4().hex[:8]
    s3_key = f"uploads/{ts}-{uid}-{req.filename}"

    # ── Step 1: put object in S3 ──────────────────────────────────────────────
    try:
        s3.put_object(
            Bucket=S3_BUCKET,
            Key=s3_key,
            Body=req.content.encode("utf-8"),
            ContentType="text/plain",
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"S3 upload failed: {exc}") from exc

    # ── Step 2: enqueue SQS message ───────────────────────────────────────────
    message = {
        "event": "file.uploaded",
        "bucket": S3_BUCKET,
        "key": s3_key,
        "filename": req.filename,
        "uploaded_at": datetime.now(timezone.utc).isoformat(),
    }

    try:
        queue_url = get_queue_url()
        resp = sqs.send_message(
            QueueUrl=queue_url,
            MessageBody=json.dumps(message),
            # MessageGroupId is required for FIFO queues — omitted here (standard queue)
        )
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"SQS send failed: {exc}") from exc

    return {
        "s3_key": s3_key,
        "sqs_message_id": resp["MessageId"],
        "message": "File uploaded and processing job enqueued.",
    }


@app.get("/files")
def list_files() -> dict:
    """Return all objects currently stored in the S3 bucket."""
    try:
        resp = s3.list_objects_v2(Bucket=S3_BUCKET)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"S3 list failed: {exc}") from exc

    objects = [
        {
            "key": obj["Key"],
            "size_bytes": obj["Size"],
            "last_modified": obj["LastModified"].isoformat(),
        }
        for obj in resp.get("Contents", [])
    ]
    return {"bucket": S3_BUCKET, "count": len(objects), "objects": objects}