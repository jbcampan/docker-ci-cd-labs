# Lab 03 — Image Optimization (Multi-Stage Build)

## Objective

Drastically reduce the size of a Docker image using a multi-stage build.

Reduce a Flask application's image size from approximately **400 MB** to **40 MB** while keeping the same functionality.

## What You'll Create

* `Dockerfile.naive` — unoptimized reference image
* `Dockerfile` — optimized multi-stage build
* Unit tests executed during the builder stage

## What You'll Learn

| Concept                 | Description                                                                   |
| ----------------------- | ----------------------------------------------------------------------------- |
| Multi-stage build       | Multiple `FROM` instructions in a Dockerfile; only the final stage is shipped |
| `COPY --from`           | Copies artifacts from a previous build stage                                  |
| Image size optimization | Fewer layers and tools result in a smaller attack surface                     |
| Non-root user           | A standard security best practice for production environments                 |

## Estimated Cost

€0 — 100% local.

## Prerequisites

* Lab 02 completed

## Steps

### 1. Build and Compare Both Images

```bash
# Naive image
docker build -f Dockerfile.naive -t flask-naive .
docker images flask-naive

# Optimized image
docker build -f Dockerfile -t flask-optimized .
docker images flask-optimized

# Compare directly
docker images | grep flask
```

### 2. Verify That the Application Runs Correctly

```bash
docker run -d --name flask-opt -p 5000:5000 flask-optimized
curl http://localhost:5000
docker stop flask-opt && docker rm flask-opt
```

### 3. Inspect the Final Image Contents

```bash
# Open a shell inside the optimized image
docker run -it --entrypoint sh flask-optimized

# Verify:
whoami          # appuser — not root
which gcc       # empty — no compilation tools
which pip       # may be absent
ls /app         # only app.py
exit
```

## Key Questions

* What is included in the final image when using a multi-stage build?
* Why should containers run as a non-root user?
* In which scenarios would you use three or more build stages?
* What are the differences between `python:3.11`, `python:3.11-slim`, and `python:3.11-alpine`?

## Useful Links

* Docker Multi-Stage Builds: https://docs.docker.com/build/building/multi-stage/
* Python Official Docker Images: https://hub.docker.com/_/python
