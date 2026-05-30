# Lab 02 — First Dockerfile

## Objective
Write a Dockerfile to containerize a simple Python Flask application.
Understand instruction order and its impact on Docker build cache.

## What You Build
- A minimal Flask app with 2 routes
- A fully commented Dockerfile
- A locally built and tagged Docker image

## What You Learn
| Concept | Explanation |
|---|---|
| FROM | Base image — prefer slim or alpine variants when possible |
| WORKDIR | Sets the working directory inside the container |
| COPY | Copies files from host to container |
| RUN | Executes a command during build (creates a layer) |
| EXPOSE | Documents the container port (does not publish it) |
| CMD | Default command executed when the container starts |
| .dockerignore | Excludes unnecessary files from the build context |
| Cache Docker | Layers are cached — instruction order matters |

## Estimated Cost
0 € — fully local.

## Prerequisites
- Lab 01 completed
- No Python installation required on the host (everything runs inside the container)

## Steps

### 1. Build the Image
```bash
# From the lab root directory
docker build -t flask-app:v1 .

# Inspect generated layers
docker image history flask-app:v1
```

### 2. Run the Container
```bash
docker run -d \
  --name flask-app \
  -p 5000:5000 \
  flask-app:v1

# Test endpoints
curl http://localhost:5000
curl http://localhost:5000/health
```

### 3. Observe Docker Cache Behavior
```bash
# Modify app/app.py (change the message)
# Rebuild and observe cached layers
docker build -t flask-app:v2 .
# → pip install step is cached (cache hit)

# Now modify requirements.txt
# Rebuild again
docker build -t flask-app:v3 .
# → pip install runs again (cache miss)
# → all subsequent layers are rebuilt
```

### 4. Cleanup
```bash
docker stop flask-app
docker rm flask-app
docker rmi flask-app:v1 flask-app:v2 flask-app:v3
```

## Key Questions
- Why copy requirements.txt before the rest of the application code?
- What happens if you run COPY app/ . before RUN pip install?
- What is the difference between CMD and ENTRYPOINT?
- Why use --no-cache-dir with pip installs?

## Useful Links
- https://docs.docker.com/reference/dockerfile/
- https://docs.docker.com/build/cache/