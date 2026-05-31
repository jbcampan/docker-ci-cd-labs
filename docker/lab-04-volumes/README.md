# Lab 04 — Volumes and Data Persistence

## Objective

Understand why container data is ephemeral by default and how to persist it using Docker volumes.

## What You Will Build

* A Flask application with a SQLite database stored in `/data`
* A demonstration of data loss without a volume
* A named volume for persistent storage
* A bind mount for live-reload during development

## What You Will Learn

| Concept              | Explanation                                                                                |
| -------------------- | ------------------------------------------------------------------------------------------ |
| Ephemeral by Default | Any data written inside a container is lost when the container is removed with `docker rm` |
| Named Volume         | Docker-managed storage that persists independently of containers                           |
| Bind Mount           | Mounts a host directory into a container — ideal for development                           |
| `VOLUME` Instruction | Documents mount points in the Dockerfile                                                   |

## Estimated Cost

€0 — 100% local.

## Prerequisites

* Lab 02 completed

## Steps

### 1. Demonstrate Data Loss Without a Volume

```bash
docker build -t flask-notes .

# Run WITHOUT a volume
docker run -d --name notes-ephemeral -p 5000:5000 flask-notes

# Create some data
curl -X POST http://localhost:5000/notes \
  -H "Content-Type: application/json" \
  -d '{"content": "Important note"}'

curl http://localhost:5000/notes   # → the note exists

# Remove the container
docker rm -f notes-ephemeral

# Start it again
docker run -d --name notes-ephemeral -p 5000:5000 flask-notes
curl http://localhost:5000/notes   # → empty. Data is gone.

docker rm -f notes-ephemeral
```

### 2. Named Volume — Guaranteed Persistence

```bash
# Create a named volume
docker volume create notes-data

# Run with the volume
docker run -d --name notes-persist \
  -p 5000:5000 \
  -v notes-data:/data \
  flask-notes

# Create some data
curl -X POST http://localhost:5000/notes \
  -H "Content-Type: application/json" \
  -d '{"content": "This note will survive"}'

# Remove the container
docker rm -f notes-persist

# Restart using the SAME volume
docker run -d --name notes-persist \
  -p 5000:5000 \
  -v notes-data:/data \
  flask-notes

curl http://localhost:5000/notes   # → the note is still there
```

### 3. Inspect and Manage Volumes

```bash
docker volume ls
docker volume inspect notes-data

# → Displays the actual path on the host
#   (/var/lib/docker/volumes/...)
```

### 4. Bind Mount for Development

```bash
# Mount local source code into the container (live reload)
docker run -d --name notes-dev \
  -p 5000:5000 \
  -v $(pwd)/app:/app \
  -v notes-data:/data \
  flask-notes

# Edit app/app.py on the host → the container sees the changes
# (Flask debug mode automatically reloads the application)
```

### 5. Cleanup

```bash
docker rm -f notes-persist notes-dev
docker volume rm notes-data
```

## Knowledge Check

* What is the difference between a named volume and a bind mount?
* Where does Docker physically store volumes on a Linux host?
* In what situation would you use a bind mount in production? (Answer: never)
* How can two containers share the same volume?

## Useful Links

* https://docs.docker.com/storage/volumes/
* https://docs.docker.com/storage/bind-mounts/
