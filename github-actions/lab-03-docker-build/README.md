# Lab 03 — Docker Build in CI

## Objective

Build a Docker image inside GitHub Actions, push it to GitHub Container Registry (GHCR),
and verify the pushed image is actually pullable — the bridge between code and deployment.

## Structure

```
docker-ci-cd-labs/                               # repo root
├── .github/
│   └── workflows/
│       └── github-actions-lab-03.yml            # CI pipeline (3 jobs)
└── github-actions/
    └── lab-03-docker-build/
        ├── README.md                            # this file
        ├── .dockerignore                        # keeps the build context clean
        ├── Dockerfile                           # multi-stage build (deps + runtime)
        └── app/
            ├── main.py                          # FastAPI app — / and /health routes
            ├── requirements.txt                 # Python dependencies
            └── test_main.py                     # pytest unit tests
```

## What you build

| Artifact | Description |
|---|---|
| FastAPI app | Minimal app with `/` and `/health` endpoints |
| Multi-stage Dockerfile | `deps` stage isolates pip install; `runtime` stage is lean and runs as non-root |
| CI pipeline | 3 jobs in sequence: `test → build-and-push → verify` |
| GHCR image | Tagged `latest` + `sha-<short>` on every push to `main` |

## What you learn

| Concept | Explanation |
|---|---|
| `docker/build-push-action` | The official Docker action; handles buildx, push, OCI labels, and multi-platform builds in one step |
| GHCR (`ghcr.io`) | GitHub's own container registry; authentication via the automatic `GITHUB_TOKEN`, no external account needed |
| `cache-from` / `cache-to` with `type=gha` | Stores layer cache in the GitHub Actions cache between runs; drastically reduces build time when unchanged layers are reused |
| SHA tagging | `sha-<short>` tags are immutable and traceable — you can always find which commit produced which image |
| `docker/metadata-action` | Automatically generates tags and OCI labels from the git context (branch, SHA, timestamp) |
| `needs:` | Job dependency declaration — `build-and-push` only starts if `test` succeeded |
| `push: ${{ github.event_name != 'pull_request' }}` | Build on PRs (validate the Dockerfile), push only on merge (keep the registry clean) |
| `permissions: packages: write` | Explicit permission scope required for GHCR push since late 2022 |

## Estimated cost

**$0** — GHCR is free for public repositories. For private repos, the free tier includes
500 MB storage and 1 GB transfer/month (included in GitHub Free and Pro plans).

## Prerequisites

- A GitHub repository (public or private)
- The workflow file committed at `.github/workflows/github-actions-lab-03.yml` on `main`
- No secrets to configure — `GITHUB_TOKEN` is injected automatically by GitHub Actions

## Steps

### 1 — Place the files in your repo

```
docker-ci-cd-labs/
├── .github/workflows/github-actions-lab-03.yml
└── github-actions/lab-03-docker-build/
    ├── .dockerignore
    ├── Dockerfile
    └── app/
        ├── main.py
        ├── requirements.txt
        └── test_main.py
```

### 2 — Push to main and watch the pipeline

```bash
git add .github/workflows/github-actions-lab-03.yml \
        github-actions/lab-03-docker-build/
git commit -m "feat(lab-03): docker build CI with GHCR push"
git push origin main
# → Go to the Actions tab and watch the 3 jobs run in sequence
```

### 3 — Inspect the produced tags

```bash
# Replace <OWNER> and <REPO> with your GitHub username and repository name
docker pull ghcr.io/<OWNER>/<REPO>/lab-03-app:latest
docker pull ghcr.io/<OWNER>/<REPO>/lab-03-app:sha-<SHORT_SHA>

# Run locally to confirm it works
docker run --rm -p 8000:8000 \
  ghcr.io/<OWNER>/<REPO>/lab-03-app:latest

curl http://localhost:8000/health
# Expected: {"status":"healthy"}
```

### 4 — Make the package public (optional)

After the first successful push, the package appears in the **Packages** tab of your
GitHub profile. By default it is private. To pull locally without `docker login`:

`https://github.com/users/<OWNER>/packages/container/lab-03-app/settings`
→ Change visibility to **Public**.

### 5 — Observe the layer cache on the second run

```bash
# Make a trivial change and push again
echo "# cache test" >> github-actions/lab-03-docker-build/app/main.py
git add . && git commit -m "chore: trigger cache test" && git push

# In the Actions run, expand "Build and push Docker image"
# Most layers should appear as CACHED — only the changed layer rebuilds
```

### 6 — Inspect OCI labels on the image

```bash
docker inspect ghcr.io/<OWNER>/<REPO>/lab-03-app:latest \
  | jq '.[0].Config.Labels'
# Shows: org.opencontainers.image.source, .revision, .created, .version, etc.
```

## Key concepts

**Why `type=gha` for the cache instead of `type=registry`?**
`type=gha` uses the GitHub Actions cache API — it is free, fast, and does not consume
registry storage. `type=registry` pushes cache manifests directly to the registry,
which is better suited for self-hosted runners or when the GHA cache quota (10 GB) is full.

**Why two tags (`latest` + `sha-`)?**
`latest` is a mutable pointer — useful for "give me the current version".
`sha-<short>` is immutable — it permanently identifies the exact commit that produced
the image. In production deployments, always reference the SHA tag, never `latest`,
to guarantee reproducibility.

**Why `push: ${{ github.event_name != 'pull_request' }}`?**
On a PR you want to validate that the image *builds* without polluting the registry
with images from unmerged branches. The build still runs (catching broken Dockerfiles
early), but the push is skipped until the PR is merged.

**Why is `permissions: packages: write` required?**
Since late 2022, GitHub enforces explicit permission scopes in workflow files.
Without it, the `GITHUB_TOKEN` is read-only for packages and the push returns HTTP 403.

**Why is `verify` a separate job?**
Separation of concerns: `build-and-push` is responsible for producing the artifact;
`verify` is responsible for asserting it is consumable. If the push succeeded but
the image is corrupted or the health check fails, `verify` catches it independently
and the failure is clearly attributed.

## Useful links

- [docker/build-push-action](https://github.com/docker/build-push-action)
- [docker/metadata-action](https://github.com/docker/metadata-action)
- [docker/login-action](https://github.com/docker/login-action)
- [GitHub Container Registry — official docs](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [GitHub Actions cache — usage limits and eviction](https://docs.github.com/en/actions/using-workflows/caching-dependencies-to-speed-up-workflows#usage-limits-and-eviction-policy)
- [OCI Image spec — annotations](https://github.com/opencontainers/image-spec/blob/main/annotations.md)
