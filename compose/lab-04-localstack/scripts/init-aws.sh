#!/bin/bash
# init-aws.sh — Bootstraps LocalStack resources at startup.
#
# Runs as a one-shot container after LocalStack is healthy.
# Uses AWS CLI v2 with --endpoint-url pointing to LocalStack.
# Idempotent: safe to run multiple times (create-* commands are no-ops if resource exists).

set -euo pipefail

ENDPOINT="http://localstack:4566"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
BUCKET="${S3_BUCKET:-lab04-bucket}"
QUEUE="${SQS_QUEUE_NAME:-lab04-queue}"

echo "==> Waiting for LocalStack to be fully ready..."
# Belt-and-suspenders: the healthcheck already gates us, but SQS/S3 service
# readiness can lag slightly behind the /health endpoint.
sleep 2

echo "==> Creating S3 bucket: ${BUCKET}"
# us-east-1 is special: it does NOT accept a LocationConstraint argument.
# Every other region requires --create-bucket-configuration LocationConstraint=<region>.
if [ "${REGION}" = "us-east-1" ]; then
  aws s3api create-bucket \
    --bucket "${BUCKET}" \
    --region "${REGION}" \
    --endpoint-url "${ENDPOINT}" \
    2>&1 | grep -v "BucketAlreadyOwnedByYou" || true
else
  aws s3api create-bucket \
    --bucket "${BUCKET}" \
    --region "${REGION}" \
    --create-bucket-configuration LocationConstraint="${REGION}" \
    --endpoint-url "${ENDPOINT}" \
    2>&1 | grep -v "BucketAlreadyOwnedByYou" || true
fi
echo "    Bucket '${BUCKET}' ready."

echo "==> Creating SQS queue: ${QUEUE}"
aws sqs create-queue \
  --queue-name "${QUEUE}" \
  --region "${REGION}" \
  --endpoint-url "${ENDPOINT}"
echo "    Queue '${QUEUE}' ready."

echo "==> Verifying resources..."
echo "--- S3 buckets ---"
aws s3api list-buckets \
  --endpoint-url "${ENDPOINT}" \
  --query "Buckets[].Name" \
  --output text

echo "--- SQS queues ---"
aws sqs list-queues \
  --endpoint-url "${ENDPOINT}" \
  --query "QueueUrls" \
  --output text

echo "==> Initialisation complete."