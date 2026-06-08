"""
worker/main.py — SQS consumer service.

Polls the SQS queue in a long-poll loop.
For each message:
  1. Parse the JSON payload to find the S3 key.
  2. Download the file content from S3.
  3. Process it (count words — trivial but illustrative).
  4. Write a result file back to S3 under results/<original-key>.
  5. Delete the message from the queue (acknowledge success).

On any processing error the message is NOT deleted, so it becomes
visible again after the visibility timeout and can be retried.
"""

import json
import logging
import os
import sys
import time
from datetime import datetime, timezone

import boto3
from botocore.exceptions import ClientError

# ── Logging ───────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
    stream=sys.stdout,
)
log = logging.getLogger("worker")

# ── Config ────────────────────────────────────────────────────────────────────
S3_BUCKET = os.environ["S3_BUCKET"]
SQS_QUEUE_NAME = os.environ["SQS_QUEUE_NAME"]
POLL_WAIT_TIME = int(os.environ.get("POLL_WAIT_TIME", "5"))
VISIBILITY_TIMEOUT = int(os.environ.get("VISIBILITY_TIMEOUT", "30"))

session = boto3.session.Session()
s3 = session.client("s3")
sqs = session.client("sqs")


# ── Helpers ───────────────────────────────────────────────────────────────────

def get_queue_url() -> str:
    resp = sqs.get_queue_url(QueueName=SQS_QUEUE_NAME)
    return resp["QueueUrl"]


def process_message(payload: dict) -> str:
    """
    Business logic placeholder.

    Downloads the uploaded file from S3, counts words, and returns a
    summary string. Replace this function with real processing logic.
    """
    bucket = payload["bucket"]
    key = payload["key"]
    filename = payload.get("filename", key)

    log.info("  Downloading s3://%s/%s", bucket, key)
    obj = s3.get_object(Bucket=bucket, Key=key)
    content = obj["Body"].read().decode("utf-8")

    word_count = len(content.split())
    char_count = len(content)

    result = (
        f"Processed: {filename}\n"
        f"  Words:      {word_count}\n"
        f"  Characters: {char_count}\n"
        f"  Preview:    {content[:120]!r}\n"
        f"  Processed at: {datetime.now(timezone.utc).isoformat()}\n"
    )
    return result


def save_result(original_key: str, result: str) -> str:
    """Write the processing result to S3 and return the result key."""
    # e.g. uploads/20240101-120000-abc-file.txt → results/uploads/20240101-120000-abc-file.txt
    result_key = f"results/{original_key}"
    s3.put_object(
        Bucket=S3_BUCKET,
        Key=result_key,
        Body=result.encode("utf-8"),
        ContentType="text/plain",
    )
    return result_key


# ── Main polling loop ─────────────────────────────────────────────────────────

def poll(queue_url: str) -> None:
    """
    Receive up to 10 messages per API call (SQS maximum).

    WaitTimeSeconds enables long polling: SQS holds the connection open for
    up to POLL_WAIT_TIME seconds waiting for a message before returning empty.
    This reduces empty-receive costs vs. short polling (tight loop + sleep).
    """
    resp = sqs.receive_message(
        QueueUrl=queue_url,
        MaxNumberOfMessages=10,
        WaitTimeSeconds=POLL_WAIT_TIME,
        VisibilityTimeout=VISIBILITY_TIMEOUT,
        AttributeNames=["All"],
        MessageAttributeNames=["All"],
    )

    messages = resp.get("Messages", [])
    if not messages:
        return  # Normal: no messages during this poll window

    log.info("Received %d message(s)", len(messages))

    for msg in messages:
        receipt_handle = msg["ReceiptHandle"]
        message_id = msg["MessageId"]

        try:
            payload = json.loads(msg["Body"])
            log.info("Processing message %s | event=%s | key=%s",
                     message_id, payload.get("event"), payload.get("key"))

            result = process_message(payload)
            result_key = save_result(payload["key"], result)

            log.info("  ✓ Result saved to s3://%s/%s", S3_BUCKET, result_key)

            # ── ACK: delete message only after successful processing ──────────
            # If we crash between processing and deleting, the message becomes
            # visible again after VISIBILITY_TIMEOUT — this is the "at-least-once"
            # delivery guarantee of SQS.
            sqs.delete_message(QueueUrl=queue_url, ReceiptHandle=receipt_handle)
            log.info("  ✓ Message %s deleted from queue", message_id)

        except ClientError as exc:
            log.error("AWS error for message %s: %s", message_id, exc)
            # Do NOT delete — let SQS redeliver after visibility timeout

        except Exception as exc:  # noqa: BLE001
            log.error("Processing error for message %s: %s", message_id, exc, exc_info=True)
            # Do NOT delete — let SQS redeliver after visibility timeout


def main() -> None:
    log.info("Worker starting...")
    log.info("  Queue:   %s", SQS_QUEUE_NAME)
    log.info("  Bucket:  %s", S3_BUCKET)
    log.info("  WaitTime: %ss | VisibilityTimeout: %ss",
             POLL_WAIT_TIME, VISIBILITY_TIMEOUT)

    # Wait for LocalStack init to complete (belt-and-suspenders)
    time.sleep(3)

    queue_url = get_queue_url()
    log.info("Queue URL: %s", queue_url)
    log.info("Worker ready — polling for messages...")

    while True:
        try:
            poll(queue_url)
        except KeyboardInterrupt:
            log.info("Worker stopped by user.")
            sys.exit(0)
        except Exception as exc:  # noqa: BLE001
            log.error("Unexpected error in poll loop: %s", exc, exc_info=True)
            time.sleep(5)   # Back off before retrying


if __name__ == "__main__":
    main()