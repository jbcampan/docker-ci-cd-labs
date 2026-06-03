# Lab 02 — Variables & Config

## Objective

Externalize all configuration of a Compose stack via `.env` files and profiles.
Never hardcode a value that changes between dev and prod.

---

## What you build

| File | Role |
|---|---|
| `.env` | Dev variables (gitignored) |
| `.env.prod` | Prod variables (gitignored) |
| `.env.example` | Committed template, no secrets |
| `docker-compose.yml` | Base stack (web + db + adminer) |
| `docker-compose.override.yml` | Dev overrides, merged automatically |
| `docker-compose.prod.yml` | Prod overrides, applied explicitly |

---

## What you learn

### `env_file` vs `environment`: two distinct mechanisms

| | `env_file` | `environment` |
|---|---|---|
| **What it does** | Loads an entire file into the container | Declares variables one by one in the YAML |
| **Visibility in YAML** | None — keys stay in the file | Explicit — you see exactly what is injected |
| **Use case** | Credentials, many variables, secrets | Punctual overrides, structural variables |
| **`${VAR}` interpolation** | No (file values are raw) | Yes — Compose resolves `${VAR}` from the shell or `.env` |
| **Risk of leaking in logs** | Low if `.env` is gitignored | Low, but values appear in `docker compose config` |

**Practical rule**: `env_file` for secrets, `environment` for the few variables that change predictably based on context.

---

### The override (merge) mechanism

When you run `docker compose up`, Compose automatically merges in order:

```
docker-compose.yml                  ← base
  + docker-compose.override.yml     ← applied by default if present
```

To add a file explicitly (prod):

```
docker-compose.yml
  + docker-compose.prod.yml         ← requires the -f flag
```

**Merge rule**: scalar keys (image, command…) are replaced. Lists (`volumes`, `ports`, `environment`) are **concatenated**. To reset a list, use `!reset []`.

---

### Compose profiles

A profile is an optional tag on a service. Without `--profile`, only services **without a profile** start.

```yaml
services:
  adminer:
    profiles:
      - dev      # only starts with --profile dev
```

```bash
docker compose --profile dev up      # web + db + adminer
docker compose --profile prod up     # web + db only
```

---

### Why `.env` belongs in `.gitignore`

`.env` contains passwords, tokens and secrets. Committing them:
- exposes credentials in Git history (even after deletion)
- blocks secret rotation (the old hash stays in the repo)

**Recommended pattern**: commit `.env.example` (empty or fake values), copy it to `.env` locally and fill it in.

---

## Estimated cost

**$0** — 100% local, no cloud resources.

---

## Prerequisites

- Docker Desktop ≥ 4.x or Docker Engine + Compose plugin
- Lab 01 completed (basic Dockerfile mastered)

---

## Steps

### 1. Prepare the local environment

```bash
# Copy the template and fill in the variables
cp .env.example .env

# Verify that .env is properly ignored by git
git check-ignore -v .env
# expected: .gitignore:2:.env    .env
```

### 2. Inspect the resolved config before starting

```bash
# Displays the merged stack (docker-compose.yml + override) with resolved variables
# Useful for debugging before launching anything
docker compose config
```

> **What you observe**: all `${VAR}` placeholders are replaced by their real values.
> Secrets appear in plain text here — never share this output.

### 3. Start the development stack

```bash
# Start the "dev" profile services (web + db + adminer)
# The override is merged automatically
docker compose --profile dev up --build
```

```bash
# In another terminal — check variables injected into the web container
docker compose exec web env | sort
```

```bash
# Test the application endpoint
curl http://localhost:8080/
# expected: JSON with env=dev, debug=true, features.dark_mode=true
```

```bash
# Adminer is available at http://localhost:8081
# Server: db | User: appuser | Password: supersecretdev | Database: appdb
```

### 4. Observe hot-reload (thanks to the override bind-mount)

```bash
# Edit app/main.py — add a key to the JSON response, for example:
#   "lab": "02-variables"
# Save, then immediately:
curl http://localhost:8080/
# The new key appears without a rebuild — Flask reloaded automatically
```

### 5. Simulate production mode

```bash
# Stop the dev stack
docker compose --profile dev down

# Start explicitly with prod files and .env.prod
docker compose \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  --env-file .env.prod \
  --profile prod \
  up --build -d
```

```bash
# Verify the differences: debug=false, analytics=true, port 80
curl http://localhost:80/
```

```bash
# Confirm the DB port is no longer exposed in prod
docker compose \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  --env-file .env.prod \
  --profile prod \
  config | grep -A10 "name: db" | grep -c "published"
# expected: 0  ← no published port
```

### 6. Compare both configs side by side

```bash
# Dev (with automatic override)
docker compose --profile dev config > /tmp/config-dev.yml

# Prod (with explicit override)
docker compose \
  -f docker-compose.yml \
  -f docker-compose.prod.yml \
  --env-file .env.prod \
  --profile prod \
  config > /tmp/config-prod.yml

diff /tmp/config-dev.yml /tmp/config-prod.yml
```

### 7. Clean up

```bash
docker compose --profile dev down -v    # -v also removes the db_data volume
docker compose --profile prod down -v
```

---

## Key takeaways

1. **`docker compose config` resolves variables** — it is your best debugging tool before launching anything. If a variable appears empty, the problem is there.

2. **The automatic override is a convention, not a requirement** — `docker-compose.override.yml` is loaded if present. You can rename it `docker-compose.dev.yml` and pass it with `-f` for more explicit control.

3. **`!reset []` on lists** — without it, `ports` in prod would contain the union of base + override ports. The `!reset` directive is the only way to clear an inherited list.

4. **Profiles do not replace files** — a profile activates/deactivates services. A `-f` file changes the configuration of services. The two are orthogonal and can be combined.

5. **`env_file` + `environment` coexist** — `environment` is applied after `env_file`. It can therefore overwrite a value loaded from the file. This is useful for punctual overrides without modifying `.env`.

---

## Useful links

- [Compose file reference — `env_file`](https://docs.docker.com/compose/compose-file/05-services/#env_file)
- [Compose file reference — `environment`](https://docs.docker.com/compose/compose-file/05-services/#environment)
- [Merge rules (override files)](https://docs.docker.com/compose/how-tos/multiple-compose-files/merge/)
- [Profiles documentation](https://docs.docker.com/compose/how-tos/profiles/)
- [Variable interpolation](https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/)