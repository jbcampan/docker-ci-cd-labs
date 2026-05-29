# Lab 01 — First Container

## Objective

Understand the lifecycle of a container and the fundamental difference between an image and a container.

## What You Build

No application files — this lab is entirely command-line based.

## What You Learn

| Concept            | Explanation                                                                            |
| ------------------ | -------------------------------------------------------------------------------------- |
| Image vs Container | An image is an immutable blueprint. A container is the running instance of that image. |
| Layers             | A Docker image is made of stacked read-only layers.                                    |
| Lifecycle          | created → running → stopped → removed                                                  |
| Isolation          | Each container has its own filesystem, network, and process space.                     |

## Estimated Cost

€0 — fully local, no AWS resources required.

## Prerequisites

* Docker Desktop installed (Mac/Windows) or Docker Engine (Linux)
* Verify installation with:

```bash
docker --version
```

## Steps

### 1. Verify Docker Installation

```bash
docker --version
docker info
```

### 2. Run Your First Interactive Container

```bash
# Download the Alpine image (~7 MB) and open a shell inside it
docker run -it alpine sh

# Inside the container:
cat /etc/os-release   # Linux distribution information
whoami                # you are root by default
ps aux                # only the shell process is running
ls /                  # isolated filesystem
exit                  # stop the container
```

### 3. Observe the Container Lifecycle

```bash
# Start a container in detached mode
docker run -d --name my-nginx nginx

# Running containers
docker ps

# All containers (including stopped ones)
docker ps -a

# Container logs
docker logs my-nginx

# Open a shell inside the running container
docker exec -it my-nginx sh
  ls /usr/share/nginx/html
  exit
```

### 4. Inspect Image Layers

```bash
# View nginx image layer history
docker image history nginx

# Full container metadata
docker inspect my-nginx
```

### 5. Cleanup

```bash
docker stop my-nginx
docker rm my-nginx
docker rmi nginx
docker system prune     # remove unused Docker resources
```

## Key Questions

* What is the difference between `docker run` and `docker start`?
* Why is Alpine Linux so lightweight (~7 MB)?
* What happens to data written inside a container after `docker rm`?
* What is the AWS equivalent of a Docker image?

## Useful Links

* Docker Getting Started: https://docs.docker.com/get-started/
* Docker Hub (public registry): https://hub.docker.com
