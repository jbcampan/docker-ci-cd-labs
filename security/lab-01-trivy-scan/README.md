# Lab 01 — Trivy Image Scan

## Objective

Integrate Trivy into a GitHub Actions pipeline to automatically scan every Docker
image before any push to a registry.

The deployment is blocked as soon as a `CRITICAL` severity CVE is detected.
The lab runs in two phases:

- **Phase A** — vulnerable image (`python:3.8-slim-buster`, Debian Buster EOL):
  observe the pipeline blocking and read the SARIF report in the Security tab.
- **Phase B** — fixed image (`python:3.13-slim`, Debian Bookworm):
  validate that the pipeline turns green again.

Pipeline implemented:

```
build → scan SARIF (all severities) → upload GitHub Security
                                     ↓
                                block on CRITICAL  ──✗──→ job fails (push never reached)
                                     ↓ (pass)
                                warn on HIGH       ──→ logs only, pipeline continues
                                     ↓
                                push to ECR        ──→ (placeholder, unlocked here)
```

---

## Structure

```
docker-ci-cd-labs/                                 # repository root
├── .github/
│   └── workflows/
│       └── security-lab-01.yml                   # CI pipeline (must live at repo root)
└── security/
    └── lab-01-trivy-scan/
        ├── README.md                              # this file
        ├── app/
        │   ├── main.py                            # Flask app — routes / and /health
        │   └── requirements.txt                  # flask==3.0.3
        ├── Dockerfile                             # vulnerable image (Phase A)
        ├── Dockerfile.fixed                       # fixed image     (Phase B)
        ├── .dockerignore                          # excludes Python cache, .git, Dockerfile.fixed…
        └── .trivyignore                           # CVE suppressions with mandatory justification
```

---

## What You Build

| File | Role |
|---|---|
| `security-lab-01.yml` | CI workflow: build → trivy scan (3 severity levels) → conditional push |
| `Dockerfile` | Vulnerable image based on `python:3.8-slim-buster` (Debian Buster, EOL) |
| `Dockerfile.fixed` | Fixed image based on `python:3.13-slim` (Debian Bookworm) |
| `app/main.py` | Minimal Flask server — two routes: `/` and `/health` |
| `.trivyignore` | Documented template for accepted CVE suppressions |
| `trivy-results.sarif` | *(generated in CI)* SARIF report visible in GitHub → Security → Code scanning |

---

## What You Learn

| Concept | Explanation |
|---|---|
| **Trivy** | Open-source scanner by Aqua Security. Analyses OS packages (apt/apk), application dependencies (pip, npm, go.sum), and IaC misconfigurations. Downloads a CVE database on each run. |
| **SARIF format** | *Static Analysis Results Interchange Format* — OASIS standard natively ingested by GitHub Advanced Security. Displays each CVE with its description, severity, and location in the repo's Security tab. |
| **Threshold strategy** | `exit-code: "1"` combined with `severity: "CRITICAL"` turns a scan result into a pipeline decision: if a CRITICAL CVE is found, the job fails and the push never happens. |
| **Why scan the built image** | CVEs most often come from the base image (glibc, openssl, zlib…), not from application code. Scanning `requirements.txt` alone would never detect a `python:3.8-slim-buster` packed with OS-level CVEs. |
| **`if: always()`** | GitHub Actions condition: the step runs even if a previous step failed. Used on the SARIF upload so the report is always visible, including when the scan blocks the pipeline. |
| **`if: success()`** | GitHub Actions condition: the step runs only if all previous steps succeeded. Used on the HIGH warning so it only displays after confirming no CRITICAL CVEs are present. |
| **`.trivyignore`** | Suppression file for CVEs that have been reviewed and accepted. Every entry must be justified and dated — it is a governance decision, not a workaround. |
| **`ignore-unfixed: false`** | Trivy surfaces CVEs even when no patch is available. Setting this to `true` would only report CVEs with a published fix (more permissive, but hides real risks). |

---

## Estimated Cost

**$0**

- Trivy is open-source (Apache 2.0 licence).
- SARIF upload and the GitHub Security tab are **free for public repositories**.
- For private repositories: included in GitHub Team / Enterprise, or available
  as an add-on via GitHub Advanced Security.

---

## Prerequisites

- A **public** GitHub repository (required for free SARIF upload)
- Docker installed locally

Trivy locally (optional but recommended for iterating without pushing):

```bash
# macOS
brew install trivy

# Linux (official install script)
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
  | sh -s -- -b /usr/local/bin

# Windows
winget install aquasecurity.trivy

# Verify installation
trivy --version
```

> **Action version** — The workflow uses `aquasecurity/trivy-action@0.36.0`.
> Check the latest stable release at
> [github.com/aquasecurity/trivy-action/releases](https://github.com/aquasecurity/trivy-action/releases)
> and update the tag before using this in production.

---

## Steps

### Phase A — Observe the blocking behaviour (vulnerable image)

```bash
# 1. Move to the repository root
cd docker-ci-cd-labs

# 2. Build the vulnerable image locally
docker build \
  --tag security-lab-01:vulnerable \
  security/lab-01-trivy-scan/

# 3. Scan all severities — identical to what the CI runs
trivy image \
  --severity CRITICAL,HIGH,MEDIUM,LOW \
  --format table \
  security-lab-01:vulnerable
# → Multiple CRITICAL CVEs in the OS layer (Debian Buster, EOL)

# 4. Simulate the pipeline decision: exit-code 1 on CRITICAL
trivy image \
  --severity CRITICAL \
  --exit-code 1 \
  --format table \
  security-lab-01:vulnerable
echo "Exit code: $?"
# → Exit code: 1 — the pipeline would be blocked here

# 5. Generate a local SARIF report for inspection
trivy image \
  --severity CRITICAL,HIGH,MEDIUM,LOW \
  --format sarif \
  --output trivy-results-local.sarif \
  security-lab-01:vulnerable
# → Open trivy-results-local.sarif in VS Code or browse with jq

# 6. Push to trigger the workflow
git add .
git commit -m "feat(security): add lab-01 trivy scan with vulnerable image"
git push origin main
# → On GitHub: Actions → the job fails at step "block on CRITICAL CVEs"
# → GitHub → Security → Code scanning alerts: CVEs appear from the SARIF report
```

### Phase B — Fix the image and validate a green pipeline

```bash
# 7. Replace the Dockerfile with the fixed version
cp security/lab-01-trivy-scan/Dockerfile.fixed \
   security/lab-01-trivy-scan/Dockerfile

# 8. Verify locally that the CRITICAL scan passes
docker build \
  --tag security-lab-01:fixed \
  security/lab-01-trivy-scan/

trivy image \
  --severity CRITICAL \
  --exit-code 1 \
  --format table \
  security-lab-01:fixed
echo "Exit code: $?"
# → Exit code: 0 — pipeline unblocked

# 9. Push the fix
git add security/lab-01-trivy-scan/Dockerfile
git commit -m "fix(security): update base image to python:3.13-slim (no CRITICAL CVEs)"
git push origin main
# → The CI job turns green
# → The "warn on HIGH CVEs" step now runs (pipeline continues)
# → The "Push to ECR" step would be reached if AWS credentials were configured
```

### Phase C — Test CVE suppressions via `.trivyignore`

```bash
# 10. List HIGH CVEs found on the fixed image
trivy image \
  --severity HIGH \
  --format json \
  security-lab-01:fixed \
  | jq -r '.Results[].Vulnerabilities[]? | "\(.VulnerabilityID)  \(.PkgName)  \(.Title)"' \
  | head -10
# → Copy a CVE-ID to review

# 11. After review, add the suppression to .trivyignore
#     (replace CVE-XXXX-YYYY with the real identifier)
cat >> security/lab-01-trivy-scan/.trivyignore << 'EOF'
CVE-XXXX-YYYY
# ^ <package> — <precise technical reason>
#   Reviewed: <name>, <date> | Revisit: <condition or date>
EOF

# 12. Confirm the suppression is effective locally
trivy image \
  --severity HIGH \
  --ignorefile security/lab-01-trivy-scan/.trivyignore \
  --format table \
  security-lab-01:fixed
# → The suppressed CVE no longer appears in the output

# 13. Push — the CI will automatically pick up the updated .trivyignore
git add security/lab-01-trivy-scan/.trivyignore
git commit -m "chore(security): suppress CVE-XXXX-YYYY — accepted risk, reviewed <date>"
git push origin main
```

---

## Understanding Checks

**Why does the SARIF step run before the blocking step?**
The SARIF step (step 3) uses `exit-code: "0"` and never fails by design.
The blocking step (step 5) runs after it. If step 5 returns exit-code 1 and fails
the job, the SARIF report has already been generated. The `if: always()` condition
on the upload step (step 4) additionally guarantees that the upload happens even if
an unexpected error occurs inside the SARIF step itself.

**What is the difference between `ignore-unfixed: true` and `.trivyignore`?**
`ignore-unfixed: true` silently hides all CVEs that have no available fix — pragmatic,
but risky: a CVE without a patch is not necessarily without danger.
`.trivyignore` suppresses specific CVEs after an explicit review. Each line is a
documented, version-controlled decision. This is the recommended practice in
production environments.

**What if `python:3.13-slim` also has CRITICAL CVEs?**
This is possible: official images receive new CVEs between Debian point releases.
The workflow will block, which is the expected behaviour. Options are:
(1) wait for the next official image rebuild, (2) switch to `python:3.13-alpine`
(smaller attack surface), (3) add the CVE to `.trivyignore` after a security review.

**Why scan the built image instead of just the source code?**
`requirements.txt` only covers Python dependencies. The base image
(`python:3.8-slim-buster`) ships system libraries — glibc, openssl, zlib, curl —
that are completely outside the scope of a source code scan. An SCA
(Software Composition Analysis) tool running on source would never see them.

**How do I view alerts in GitHub Security?**
Navigate to `GitHub → <repo> → Security → Code scanning alerts`. CVEs appear with
their severity, the affected package, the vulnerable version, and the fixed version.
The tab is only visible when the repository is public or when GitHub Advanced Security
is enabled on a private repository.

---

## Useful Links

- [Trivy — official documentation](https://aquasecurity.github.io/trivy/)
- [aquasecurity/trivy-action — GitHub](https://github.com/aquasecurity/trivy-action)
- [SARIF v2.1.0 specification](https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html)
- [GitHub — Upload a SARIF file](https://docs.github.com/en/code-security/code-scanning/integrating-with-code-scanning/uploading-a-sarif-file-to-github)
- [Debian Security Tracker](https://security-tracker.debian.org/tracker/)
- [NVD — National Vulnerability Database](https://nvd.nist.gov/vuln/search)
- [python — Docker Hub (official tags)](https://hub.docker.com/_/python/tags)