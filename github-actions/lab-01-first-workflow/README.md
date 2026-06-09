# Lab 01 — First Workflow

## Objective

Set up a CI pipeline that triggers automatically on every push.
Understand the anatomy of a GitHub Actions workflow from A to Z.

---

## Structure

```
docker-cicd-labs/
├── .github/
│   └── workflows/
│       └── github-actions-lab-01.yml   # CI pipeline — must live at repo root
└── github-actions/
    └── lab-01-first-workflow/
        ├── README.md
        └── app/
            ├── app.py                  # Flask application + pure business logic
            ├── requirements.txt        # Pinned Python dependencies
            ├── pytest.ini              # pytest configuration
            └── tests/
                └── test_app.py         # Unit tests (pure functions + HTTP routes)
```

---

## What you create

| File | Purpose |
|---|---|
| `app/app.py` | A minimal Flask app with three routes and two testable pure functions |
| `app/tests/test_app.py` | 14 pytest test cases covering functions and HTTP routes |
| `app/requirements.txt` | Pinned versions of Flask, pytest, and pytest-cov |
| `app/pytest.ini` | pytest configuration (test discovery, output format) |
| `.github/workflows/github-actions-lab-01.yml` | The CI workflow triggered on push and pull request |

---

## What you learn

| Concept | Explanation |
|---|---|
| `on` | Defines the **trigger events** that start the workflow (e.g. `push`, `pull_request`). Accepts branch filters. |
| `jobs` | A workflow is made of one or more **jobs**. Each job runs on its own runner (isolated VM). |
| `steps` | Ordered list of tasks inside a job. Each step either runs a shell command or calls a pre-built action. |
| `uses` | Calls a **reusable action** published on the GitHub Marketplace (e.g. `actions/checkout@v4`). The action is a black box that does the heavy lifting. |
| `run` | Executes a **raw shell command** on the runner. Uses bash by default on `ubuntu-latest`. |
| `working-directory` | Changes the working directory for a specific step. Here used to point to the lab's `app/` subfolder since the workflow lives at repo root. |
| `ubuntu-latest` | A GitHub-managed virtual machine running Ubuntu 22.04, with ~4 GB RAM, 2 vCPUs, and a pre-installed toolchain (Python, Node, Docker, git…). GitHub provisions and tears it down automatically. |
| `matrix` | Runs the same job with several parameter combinations (here: Python 3.11 and 3.12) in parallel. |
| `cache: pip` | Caches the pip download cache between runs to reduce install time. Keyed on `requirements.txt` hash. |
| Workflow file location | GitHub Actions only scans `.github/workflows/*.yml` **at the repo root**. Workflows in subdirectories are silently ignored. |
| Reading failure logs | In the GitHub UI: **Actions tab → workflow run → failed job → expand the failing step**. Exit code, stdout, and stderr are all visible. |

---

## Estimated cost

**$0** — GitHub Actions is free for public repositories.
For **private repos**: 2 000 free minutes/month on the Free plan; `ubuntu-latest` is billed at 1× the base rate.

---

## Prerequisites

- A GitHub repository (public or private)
- The workflow file at `.github/workflows/github-actions-lab-01.yml` (repo root)
- The lab code at `github-actions/lab-01-first-workflow/app/`
- No local Python setup required to trigger the pipeline

To run the tests **locally** before pushing:

```bash
cd github-actions/lab-01-first-workflow/app
python -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt
pytest
```

---

## Steps

### 1 — Verify the file locations

```
docker-cicd-labs/
├── .github/workflows/github-actions-lab-01.yml   ← must be here
└── github-actions/lab-01-first-workflow/app/      ← lab code stays here
```

### 2 — Push and trigger the pipeline

```bash
# Any push to any branch triggers the workflow.
git add .
git commit -m "feat(github-actions): lab 01 — first CI workflow with pytest"
git push origin main
```

### 3 — Watch the pipeline run

1. Open **https://github.com/jbcampan/docker-ci-cd-labs**
2. Click the **Actions** tab in the top navigation bar (between Pull requests and Projects)
3. In the left sidebar, click the **CI** workflow
4. Click the most recent run (green = success, red = failure)
5. Click the **test** job, then click each step name to expand its log output

### 4 — Trigger a failure intentionally (learning exercise)

Edit `app/tests/test_app.py` and break one assertion:

```python
# Change this:
assert add(2, 3) == 5
# To this:
assert add(2, 3) == 99
```

```bash
git add github-actions/lab-01-first-workflow/app/tests/test_app.py
git commit -m "test: intentional failure for lab 01 exercise"
git push origin main
```

Observe the red ✗ in the Actions tab, read the failure log, then revert:

```bash
git revert HEAD
git push origin main
```

### 5 — Read the workflow syntax

Open `.github/workflows/github-actions-lab-01.yml` and match each key against the **What you learn** table above.

---

## Understanding checkpoints

1. **Why must the workflow file be at the repo root and not inside the lab folder?**
   GitHub Actions only scans `.github/workflows/` at the root of the repository. A workflow file inside `github-actions/lab-01-first-workflow/.github/workflows/` is silently ignored.

2. **What is the difference between `uses` and `run`?**
   `uses` delegates to a pre-built action (someone else's code, versioned on GitHub). `run` is a plain shell command you write yourself.

3. **Why does `actions/checkout@v4` need to be the first step?**
   The runner is a blank VM. Without checkout, the filesystem contains no source files and every subsequent step would fail.

4. **What does `cache: pip` actually cache?**
   The pip download cache (`~/.cache/pip`). On a cache hit, packages are restored instead of re-downloaded from PyPI, saving 10–30 seconds.

5. **What is a matrix build and why use it?**
   It creates N parallel jobs, one per parameter combination. Here, Python 3.11 and 3.12 run simultaneously, doubling test coverage at no extra wall-clock cost.

6. **Where do you find the exit code of a failed step?**
   In the step's expanded log inside the Actions UI. A non-zero exit code marks the step (and the job) as failed.

---

## Useful links

- [GitHub Actions quickstart](https://docs.github.com/en/actions/quickstart)
- [Workflow syntax reference](https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions)
- [actions/checkout](https://github.com/actions/checkout)
- [actions/setup-python](https://github.com/actions/setup-python)
- [GitHub-hosted runners — software installed](https://docs.github.com/en/actions/using-github-hosted-runners/using-github-hosted-runners/about-github-hosted-runners)
- [Billing for GitHub Actions](https://docs.github.com/en/billing/managing-billing-for-your-products/managing-billing-for-github-actions/about-billing-for-github-actions)
- [pytest documentation](https://docs.pytest.org/en/stable/)