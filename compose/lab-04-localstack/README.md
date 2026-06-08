# Lab 04 — Compose + LocalStack (AWS local)

## Objective

Simulate AWS services (S3, SQS) locally using LocalStack inside a Compose stack.
Develop and test AWS integrations without spending a cent or needing a real AWS account.

---

## Structure

```
lab-04-compose-localstack/
├── .env.example                # All configurable variables — copy to .env
├── docker-compose.yml          # 4 services: localstack, init, api, worker
├── scripts/
│   └── init-aws.sh             # One-shot bootstrap: creates S3 bucket + SQS queue
├── app/                        # FastAPI producer
│   ├── Dockerfile              # Multi-stage build, non-root user
│   ├── .dockerignore
│   ├── requirements.txt
│   └── main.py                 # POST /upload · GET /files · GET /health
└── worker/                     # SQS consumer
    ├── Dockerfile              # No EXPOSE — pull consumer only
    ├── .dockerignore
    ├── requirements.txt
    └── main.py                 # Long-poll loop, processes messages, writes results to S3
```

---

## What you build

| Service | Image | Role |
|---|---|---|
| `localstack` | `localstack/localstack:3.4` | Emulates S3 and SQS on port 4566 |
| `init` | `amazon/aws-cli:2.15.30` | One-shot: creates bucket + queue, then exits |
| `api` | Custom (FastAPI) | Producer: uploads files to S3, enqueues SQS messages |
| `worker` | Custom (Python) | Consumer: polls SQS, processes messages, writes results to S3 |

**Data flow:**

```
User  →  POST /upload  →  [api]
                             ├── s3.put_object()      → LocalStack S3 (uploads/<key>)
                             └── sqs.send_message()   → LocalStack SQS
                                                            ↓
                                                       [worker] (long-poll)
                                                            ├── sqs.receive_message()
                                                            ├── s3.get_object()     ← reads uploaded file
                                                            ├── process (word count)
                                                            ├── s3.put_object()     → results/<key>
                                                            └── sqs.delete_message() ← ACK
```

---

## What you learn

| Concept | Explanation |
|---|---|
| `endpoint_url` / `AWS_ENDPOINT_URL` | Redirects the entire boto3 SDK to LocalStack instead of real AWS. Set it as an env var and boto3 picks it up automatically — zero code change between local and production. |
| Producer / Consumer pattern | The API enqueues work; the worker consumes it independently. They are decoupled: the API responds immediately without waiting for processing. |
| SQS long polling | `WaitTimeSeconds > 0` keeps the connection open up to N seconds waiting for a message. Fewer empty receives = lower latency + lower cost in production. |
| Visibility timeout | When a worker receives a message, SQS hides it from other consumers for `VisibilityTimeout` seconds. If the worker crashes before deleting it, the message reappears — guaranteeing at-least-once delivery. |
| At-least-once delivery | SQS delivers every message **at least once**, but may deliver it more than once (e.g. after a crash). Your processing logic must be **idempotent** (safe to run twice). |
| `depends_on` + `condition` | Compose waits for the `localstack` healthcheck to pass before starting `init`, and waits for `init` to complete successfully before starting `api` and `worker`. |
| LocalStack free tier | Covers S3, SQS, IAM, SSM, Secrets Manager, and ~30 other services. Paid Pro tier adds ECS, RDS, ElasticSearch, etc. Always check [docs.localstack.cloud](https://docs.localstack.cloud) for the current coverage matrix. |
| Code portability | The application code is identical in local and production. Only environment variables (`AWS_ENDPOINT_URL`, credentials, bucket/queue names) differ. |

---

## Estimated cost

**€0** — 100% local, no real AWS resources.

---

## Prerequisites

- Docker Desktop (or Docker Engine + Compose plugin) running
- Port `4566` and `8000` free on your machine
- No AWS account required

---

## Steps

### 1 — Clone / enter the lab directory

```bash
cd docker-ci-cd-labs/compose/lab-04-localstack
```

### 2 — Create your .env file

```bash
# Copy the example — the defaults work as-is for local development
cp .env.example .env
```

### 3 — Start the full stack

```bash
# --build forces a fresh image build (important after code changes)
# -d runs all services in the background
docker compose --env-file .env up --build -d
```

### 4 — Verify all services are up

```bash
docker compose ps
# Expected: localstack (healthy), init (exited 0), api (healthy), worker (running)
```

### 5 — Check LocalStack initialisation logs

```bash
# Confirm the S3 bucket and SQS queue were created
docker compose logs init
# You should see: "Initialisation complete." and the resource names
```

### 6 — Check the API is reachable

```bash
curl -s http://localhost:8000/health | python3 -m json.tool
# {"status": "ok", "service": "api"}
```

### 7 — Upload a file via the API

```bash
curl -s -X POST http://localhost:8000/upload \
  -H "Content-Type: application/json" \
  -d '{"filename": "hello.txt", "content": "Hello from Lab 04! LocalStack is running locally."}' \
  | python3 -m json.tool
# Returns: s3_key, sqs_message_id
```

### 8 — Watch the worker process the message in real time

```bash
# Follow worker logs — you should see it receive, process, and ACK the message
docker compose logs -f worker
```

### 9 — List all S3 objects (uploads + results)

```bash
# Via the API
curl -s http://localhost:8000/files | python3 -m json.tool

# Or directly via AWS CLI pointed at LocalStack
aws s3 ls s3://lab04-bucket/ \
  --recursive \
  --endpoint-url http://localhost:4566 \
  --region us-east-1
```

### 10 — Read a result file directly from S3

```bash
# Replace <key> with a "results/..." key from the previous step
aws s3 cp s3://lab04-bucket/<key> - \
  --endpoint-url http://localhost:4566 \
  --region us-east-1
```

### 11 — Inspect the SQS queue (should be empty after processing)

```bash
QUEUE_URL=$(aws sqs get-queue-url \
  --queue-name lab04-queue \
  --endpoint-url http://localhost:4566 \
  --region us-east-1 \
  --query QueueUrl --output text)

aws sqs get-queue-attributes \
  --queue-url "$QUEUE_URL" \
  --attribute-names ApproximateNumberOfMessages \
  --endpoint-url http://localhost:4566 \
  --region us-east-1
# ApproximateNumberOfMessages should be "0" if the worker processed everything
```

### 12 — Send multiple messages to stress-test the worker

```bash
for i in $(seq 1 5); do
  curl -s -X POST http://localhost:8000/upload \
    -H "Content-Type: application/json" \
    -d "{\"filename\": \"batch-${i}.txt\", \"content\": \"Message number ${i} — batch test\"}" \
    | python3 -m json.tool
done
```

### 13 — Tear down

```bash
# Stop and remove containers + network (keeps the named volume)
docker compose down

# Also remove the LocalStack data volume (full reset)
docker compose down -v
```

---

## Understanding checkpoints

**Q: Why does the application code not change between local and production?**
boto3 reads `AWS_ENDPOINT_URL` from the environment before making any API call. In production, this variable is simply absent, so boto3 uses the real AWS endpoints. The bucket name, queue name, and credentials come from environment variables too — the code itself contains zero environment-specific logic.

**Q: What happens if the worker crashes mid-processing?**
The message was already received and hidden (visibility timeout started). After `VISIBILITY_TIMEOUT` seconds, SQS makes the message visible again and redelivers it to any available consumer. This is why you must not delete a message until you are sure processing succeeded.

**Q: Why does the `init` container use `restart: "no"`?**
It is a one-shot job, not a service. Without `restart: "no"`, Compose's default restart policy would re-run it every time it exits (including after a clean exit 0), re-creating resources that already exist.

**Q: What are the limits of LocalStack free tier?**
The free tier covers ~30 AWS services including S3, SQS, IAM, SSM, Lambda (basic), DynamoDB, and SNS. It does **not** cover ECS, RDS, ElasticSearch, Cognito, or AppSync — those require the Pro (paid) tier. Check [docs.localstack.cloud/references/coverage](https://docs.localstack.cloud/references/coverage/) for the full matrix.

**Q: Is SQS delivery guaranteed exactly-once?**
No. SQS standard queues guarantee **at-least-once** delivery — a message may be delivered more than once in rare cases (e.g. after a consumer crash, or due to distributed system retries). Design your processing to be **idempotent**: running it twice on the same input must produce the same result with no side effects. SQS FIFO queues offer exactly-once processing within a 5-minute deduplication window, at lower throughput.

---

## Useful links

- [LocalStack documentation](https://docs.localstack.cloud)
- [LocalStack service coverage matrix](https://docs.localstack.cloud/references/coverage/)
- [boto3 SQS API reference](https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/sqs.html)
- [boto3 S3 API reference](https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/s3.html)
- [SQS long polling explained](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-short-and-long-polling.html)
- [SQS visibility timeout](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-visibility-timeout.html)
- [FastAPI documentation](https://fastapi.tiangolo.com)