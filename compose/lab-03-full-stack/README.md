# Lab 03 — Full Stack with Health Checks & Reverse Proxy

## Objective

Orchestrate a three-service stack (PostgreSQL + Node.js API + Nginx) using Docker Compose,
with health checks on every service and conditional startup ordering via `depends_on: condition: service_healthy`.

## What You Build

| Service | Image | Role | Exposed |
|---------|-------|------|---------|
| `db` | postgres:16-alpine | Relational database | Internal only |
| `api` | Custom (Node.js 20) | Express REST API connected to PostgreSQL | Internal only |
| `nginx` | nginx:1.27-alpine | Reverse proxy — sole external entry point | `localhost:8080` |

**Volumes:** named volume `pg_data` persists database data across restarts.  
**Networks:** two isolated bridge networks (`backend`: db↔api, `frontend`: api↔nginx).

## What You Learn

| Concept | Explanation |
|---------|-------------|
| `depends_on` alone | Only waits for the container process to start — not for the service inside to be ready. PostgreSQL takes several seconds to accept connections after the process starts. |
| `condition: service_healthy` | Compose waits for the upstream service's health check to report `healthy` before starting the dependent service. Guarantees correct startup order. |
| Health check anatomy | `test`: command to run · `interval`: time between checks · `timeout`: max duration · `retries`: failures before `unhealthy` · `start_period`: grace period during startup |
| Reverse proxy role | Nginx sits in front of the API: single exposed port, hides internal topology, can add TLS termination, load balancing, and caching later. |
| Restart policies | `no` (default): never restart · `always`: always, including on Docker daemon start · `on-failure`: only on non-zero exit · `unless-stopped`: always except if manually stopped |
| Network isolation | `db` is not reachable from `nginx` — only `api` bridges both networks. Principle of least privilege at the network level. |

## Estimated Cost

**€0 — 100% local.** No cloud resources required.

## Prerequisites

- Docker Engine ≥ 25
- Docker Compose plugin (`docker compose version`)
- Node.js ≥ 20 installed locally — **only needed once** to generate `package-lock.json`
- Port `8080` free on the host

## Steps

### One-time setup — generate the lockfile

`npm ci` (used in the Dockerfile) requires a `package-lock.json` to guarantee reproducible
installs. This file must exist in `app/` before the first build.

```bash
# Generate package-lock.json without installing anything on the host
cd compose/lab-03-full-stack/app
npm install --package-lock-only

# Verify the file was created
ls package-lock.json

# Return to the lab root
cd ..
```

`--package-lock-only` resolves and writes the lockfile only — it does not create
`node_modules` on your machine. Commit `package-lock.json` alongside `package.json`;
it must be present for every subsequent `docker compose up --build`.

### Start the stack

```bash
# 1. Go to the lab directory
cd compose/lab-03-full-stack

# 2. Create your env file from the example
cp .env.example .env
# Edit .env if you want to change credentials (optional for local dev)

# 3. Build the API image and start the full stack in detached mode
docker compose up --build -d

# 4. Watch the startup sequence — observe depends_on + health checks in action
docker compose ps
# db should reach "healthy" first, then api, then nginx

# 5. Follow logs for all services (Ctrl-C to exit without stopping)
docker compose logs -f

# 6. Check individual health status
docker inspect --format='{{.State.Health.Status}}' lab03_db
docker inspect --format='{{.State.Health.Status}}' lab03_api

# 7. Test the API through nginx (nginx -> api -> db)
curl http://localhost:8080/
curl http://localhost:8080/health
curl http://localhost:8080/items

# 8. Create an item via POST
curl -s -X POST http://localhost:8080/items \
  -H "Content-Type: application/json" \
  -d '{"name": "my new item"}' | python3 -m json.tool

# 9. Verify the item was persisted in PostgreSQL directly
docker exec -it lab03_db psql -U appuser -d appdb -c "SELECT * FROM items;"

# 10. Test restart policy — simulate a crash and watch on-failure restart
#     Note: docker kill (SIGKILL) sets exit code 137 and is treated as a manual
#     stop by Docker — on-failure does NOT trigger. To test it, force a non-zero
#     exit from inside the container instead.
docker exec lab03_api node -e "process.exit(1)"
docker compose ps   # api restarts automatically — RestartCount increments
docker inspect lab03_api --format 'status={{.State.Status}} restarts={{.State.RestartCount}}'

# 11. Test volume persistence — remove containers but keep the volume
docker compose down          # stops and removes containers, keeps volumes
docker compose up -d         # recreates containers — data is still there
curl http://localhost:8080/items   # items from before are still present

# 12. Full cleanup including volume
docker compose down -v       # -v also removes named volumes
```

## Understanding Points

**1. Why is `depends_on` without `condition` insufficient ?**  
Docker starts the container as soon as the PID 1 process is launched. For PostgreSQL, the server still needs several additional seconds before it can actually accept connections. Without `condition: service_healthy`, the API would try to connect to a database that is not yet ready and would fail during startup.

**2. What happens if the `db` health check never passes ?**  
Docker Compose keeps the `api` service in a `waiting` state indefinitely. It does not start. This is the desired behavior — starting an application with an unavailable database would only hide the real underlying issue.

**3. Why are there two separate networks ?**  
The `db` service is only accessible from `api` (the `backend` network). `nginx` cannot directly reach `db`. If `nginx` is compromised, an attacker still cannot communicate with the database, improving isolation and security.

**4. What is the purpose of `start_period` in the health check ?**  
It is a grace period during which failures are not counted toward `retries`. This prevents a service from being marked as `unhealthy` while it is still initializing (for example, PostgreSQL creating its data files on first startup).

**5. What is the difference between `always` and `unless-stopped` ?**  
Both restart the container after a crash. The difference is that `always` also restarts the container when the Docker daemon itself restarts (e.g., server reboot), even if the container was previously stopped manually using `docker stop`. `unless-stopped` respects manual stops and does not restart the container in that case.

## Useful Links

- [Compose health checks](https://docs.docker.com/compose/how-tos/startup-order/)
- [Dockerfile healthcheck reference](https://docs.docker.com/reference/dockerfile/#healthcheck)
- [Compose depends_on reference](https://docs.docker.com/reference/compose-file/services/#depends_on)
- [Nginx reverse proxy guide](https://nginx.org/en/docs/http/ngx_http_proxy_module.html)
- [pg_isready documentation](https://www.postgresql.org/docs/current/app-pg-isready.html)
- [Restart policies](https://docs.docker.com/engine/containers/start-containers-automatically/#use-a-restart-policy)