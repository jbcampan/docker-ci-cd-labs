# Lab 01 — First Compose

## Objective

Orchestrate a Flask + Redis stack with Docker Compose.  
Understand how Compose replaces a series of manual `docker run` commands and handles networking automatically.

---

## What you build

| File | Role |
|---|---|
| `app/app.py` | Flask API with a visit counter stored in Redis |
| `app/Dockerfile` | Image for the Flask service |
| `app/requirements.txt` | Python dependencies |
| `docker-compose.yml` | Declares two services: `api` and `redis` |
| `.env.example` | Template for host port overrides |

The app exposes three endpoints:

| Endpoint | Behaviour |
|---|---|
| `GET /` | Increment and return the visit counter |
| `GET /health` | Check connectivity to Redis |
| `GET /reset` | Reset the counter to 0 |

---

## What you learn

### Core Compose concepts

| Concept | Where it appears in this lab |
|---|---|
| `services` | Top-level block — each key is a container |
| `build` | Points to the directory containing the Dockerfile |
| `image` | Uses an existing image from Docker Hub (Redis) |
| `ports` | `"HOST:CONTAINER"` — exposes a container port on the host |
| `environment` | Injects env vars into the container at runtime |
| `depends_on` + `condition: service_healthy` | Delays `api` startup until Redis passes its healthcheck |
| `networks` | Named bridge network — Compose creates it automatically |
| `volumes` | Named volume — persists Redis data across restarts |
| `healthcheck` | Runs `redis-cli ping` every 5 s to determine service readiness |

### Automatic DNS resolution

When two services share the same Compose network, each service is reachable
by its **service name** as a hostname.  
In `app.py`, the Redis client connects to `host="redis"` — no IP address, no
extra configuration. Compose injects a DNS entry for every service on the shared network.

### Key CLI commands

```
docker compose up --build   # build images, then start all services
docker compose up -d        # start in detached mode (background)
docker compose ps           # list running services and their status
docker compose logs -f api  # stream logs for the api service
docker compose exec api sh  # open a shell inside the running api container
docker compose stop         # stop containers without removing them
docker compose down         # stop and remove containers + network
docker compose down -v      # also remove named volumes (wipes Redis data)
```

### `up` vs `up --build`

| Command | When to use |
|---|---|
| `docker compose up` | Source code and Dockerfile haven't changed |
| `docker compose up --build` | You modified the Dockerfile or any file copied into the image |

Compose does **not** rebuild automatically when source files change — you must
pass `--build` explicitly (or use `--watch` with `develop` mode, covered in a later lab).

---

## Estimated cost

**0 € — 100 % local.** No cloud resources required.

---

## Prerequisites

- Docker Desktop (or Docker Engine + Compose plugin) installed and running
- `docker compose version` ≥ 2.20

---

## Steps

### 1 · Clone / enter the lab directory

```bash
cd compose/lab-01-first-compose
```

### 2 · (Optional) customise ports

```bash
cp .env.example .env
# Edit .env if ports 5000 or 6379 are already in use on your machine
```

### 3 · Build and start the stack

```bash
# Build the api image and start both services in the foreground
docker compose up --build
```

You should see Redis start first, pass its healthcheck, then the Flask app start.

### 4 · Test the endpoints (new terminal tab)

```bash
# Visit counter — each call increments the value
curl http://localhost:5000/
# → {"message":"Hello from Flask + Redis!","visits":1}

curl http://localhost:5000/
# → {"message":"Hello from Flask + Redis!","visits":2}

# Health check
curl http://localhost:5000/health
# → {"redis":"reachable","status":"ok"}

# Reset counter
curl http://localhost:5000/reset
# → {"message":"Counter reset to 0"}
```

### 5 · Inspect the running stack

```bash
# List services, ports, and status
docker compose ps

# Stream logs from the api service only
docker compose logs -f api

# Open a shell inside the api container
docker compose exec api sh

# From inside the container — resolve "redis" by name
# (this proves Compose DNS is working)
getent hosts redis
# → 172.x.x.x  redis
exit
```

### 6 · Inspect the automatic network

```bash
# Find the network Compose created
docker network ls | grep lab01

# Inspect it — look for the Containers section
docker network inspect lab01-first-compose_lab01_net
```

### 7 · Verify data persistence

```bash
# Stop and remove containers (keep the volume)
docker compose down

# Restart — Redis reloads from the named volume
docker compose up -d

curl http://localhost:5000/
# visits counter continues from where it left off
```

### 8 · Tear down completely

```bash
# Remove containers, network, AND the volume (fresh state)
docker compose down -v
```

---

## Comprehension questions

1. **Why can `app.py` use `host="redis"` instead of an IP address?**  
   Compose registers each service name as a DNS entry on the shared network.
   Any container on that network can resolve the name to the correct IP automatically.

2. **What does `depends_on: condition: service_healthy` add compared to plain `depends_on`?**  
   Plain `depends_on` only waits for the container to *start*, not for the process
   inside to be *ready*. With `service_healthy`, Compose polls the healthcheck and
   only starts `api` once Redis responds to `redis-cli ping`.

3. **What happens to the visit counter after `docker compose down` vs `docker compose down -v`?**  
   `down` keeps the named volume — counter survives.  
   `down -v` removes the volume — counter resets to 0 on next start.

4. **What is the difference between the `ports` mapping and the `networks` block?**  
   `ports` punches a hole from the *host* to the container (needed to `curl` from
   your machine). `networks` connects containers to each other — Redis does not
   need `ports` to be reachable by `api`.

5. **When must you run `docker compose up --build`?**  
   Any time you change the Dockerfile or a file that is `COPY`-ed into the image.
   Compose does not detect source file changes automatically.

---

## Useful links

- [Compose file reference](https://docs.docker.com/compose/compose-file/)
- [Networking in Compose](https://docs.docker.com/compose/networking/)
- [Healthchecks in Compose](https://docs.docker.com/compose/compose-file/05-services/#healthcheck)
- [docker compose CLI reference](https://docs.docker.com/compose/reference/)
- [Redis Docker Hub image](https://hub.docker.com/_/redis)
