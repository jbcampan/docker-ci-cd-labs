# Lab 05 — Docker Networking

## Objective
Get two containers communicating over a custom Docker network.
Understand Docker's internal DNS and network isolation.

## What you build
- `api` : Flask service that calls another service
- `db-service` : Flask service that exposes data
- A custom Docker network that lets them communicate by name

## What you learn
| Concept | Explanation |
|---|---|
| Bridge network | Isolated virtual network created by Docker |
| Internal DNS | Docker automatically resolves service names to IPs |
| Isolation | A container outside the network cannot communicate |
| Port mapping | `-p host:container` exposes a port to the outside |

## Estimated cost
$0 — 100% local.

## Prerequisites
- Lab 02 completed

## Steps

### 1. Build both images
```bash
docker build -t api-service ./app/api
docker build -t db-service ./app/db-service
```

### 2. Create a custom network
```bash
docker network create my-network
docker network ls
```

### 3. Start the containers on the same network
```bash
# The --name value becomes the DNS-resolvable hostname
docker run -d \
  --name db-service \
  --network my-network \
  db-service

docker run -d \
  --name api \
  --network my-network \
  -p 5000:5000 \
  api-service
```

### 4. Test inter-container communication
```bash
# The api calls db-service by name
curl http://localhost:5000/data
# → returns data from db-service
```

To verify DNS resolution **from inside** the container, open a shell:

```bash
docker exec -it api sh
```

> ⚠️ **Slim or Alpine images**: `ping` and `wget` are often **not installed** in Python slim
> (`python:3.x-slim`) or Alpine images. Don't waste time looking for them — use Python
> directly instead, which is always available:

```sh
# DNS resolution + HTTP request via Python (always available in the image)
python -c "import requests; print(requests.get('http://db-service:6000/records').json())"

# Alternative with no external dependency (urllib is built into Python)
python -c "import urllib.request; print(urllib.request.urlopen('http://db-service:6000/records').read().decode())"

exit
```

If you still want `ping` or `wget`, install them on the fly:

```sh
# On a Debian/slim image
apt-get update && apt-get install -y iputils-ping wget

# On an Alpine image
apk add --no-cache iputils wget

ping db-service          # resolved automatically
wget -qO- http://db-service:6000/records
exit
```

### 5. Demonstrate network isolation
```bash
# Start a container outside the network
docker run -it --rm alpine sh
  wget -qO- http://db-service:6000   # timeout — unreachable
  exit

# Start on the network → reachable
docker run -it --rm --network my-network alpine sh
  wget -qO- http://db-service:6000   # works
  exit
```

### 6. Inspect the network
```bash
docker network inspect my-network
# → lists connected containers and their IPs
```

### 7. Cleanup
```bash
docker rm -f api db-service
docker network rm my-network
docker rmi api-service db-service
```

## Understanding check
- What is the difference between the default `bridge` network and a custom network?
- Why does DNS work on custom networks but not on the default bridge?
- What is the AWS equivalent of a Docker network? (VPC / Security Groups)
- Why not expose `db-service` to the host with `-p`?

## Useful links
- https://docs.docker.com/network/
- https://docs.docker.com/network/bridge/