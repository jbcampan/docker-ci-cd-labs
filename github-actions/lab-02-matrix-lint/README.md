# Lab 02 — Matrix & Lint

[![CI — Matrix & Lint](https://github.com/jbcampan/docker-ci-cd-labs/actions/workflows/github-actions-lab-02.yml/badge.svg)](https://github.com/jbcampan/docker-ci-cd-labs/actions/workflows/github-actions-lab-02.yml)

---

## Objective

Run the test suite **in parallel** across multiple Python versions and add **quality gates** (lint + format check) that block merges if the code does not meet the standards.

---

## Structure

```
docker-ci-cd-labs/                          # repo root
├── .github/
│   └── workflows/
│       └── github-actions-lab-02.yml      # CI pipeline — must live here (repo root)
└── github-actions/
    └── lab-02-matrix-lint/
        ├── README.md
        ├── .flake8                        # flake8 rules (max line length, ignores)
        ├── pyproject.toml                 # black config + pytest path
        ├── requirements.txt               # pytest, flake8, black — pinned versions
        └── app/
            ├── __init__.py                # makes app/ a package (needed for imports)
            ├── calculator.py              # source module under test
            └── test_calculator.py        # pytest test suite
```

> GitHub Actions workflows **must** reside under `.github/workflows/` at the repo root regardless of where the lab code lives. The filename (`github-actions-lab-02.yml`) has no effect on behaviour — only the directory matters.

---

## What you build

| Artifact | Purpose |
|---|---|
| `lint` job | Runs **flake8** and **black --check** once, before the matrix |
| `test` matrix | Runs pytest on **Python 3.10** and **3.11** in parallel |
| `all-tests-passed` job | Single status node used by branch-protection rules |
| `concurrency` group | Cancels stale runs when a new push arrives |
| `pip` cache | Restores wheels from cache; each matrix leg has its own cache key |

---

## What you learn

| Notion | Explanation |
|---|---|
| `strategy.matrix` | Declares a set of variables; GitHub creates one parallel job per combination. Here `python-version: ["3.10", "3.11"]` → 2 concurrent jobs. |
| `fail-fast` | When `true` (default), any failing combination immediately cancels all siblings. Set to `false` to see all results even when one fails. |
| `continue-on-error` | Marks a single job as non-blocking: the overall workflow stays green even if that job fails. Useful for experimental matrix legs. |
| `needs` | Declares a dependency between jobs. The matrix does not start until `lint` succeeds — avoids wasting parallel minutes on a formatting issue. |
| `concurrency` + `cancel-in-progress` | Avoids queuing multiple runs for the same branch; only the latest push matters. |
| `actions/cache` | Persists pip's wheel cache between runs. The key includes the Python version and a hash of `requirements.txt`. |
| flake8 | Static analysis: syntax errors, undefined names, unused imports, style violations (PEP 8). Exits 1 if anything is found. |
| black `--check` | Formatter in dry-run mode. Exits 1 if any file *would* be changed. Never modifies files in CI. |
| lint vs format | **Lint** catches logic/style issues (wrong names, unused vars). **Format** enforces a canonical layout (indentation, line wrapping). Both are needed: a perfectly formatted file can still have lint errors. |

---

## Estimated cost

**€0** — GitHub Actions free tier (2 000 min/month on public repos, 500 min on private).
The matrix runs jobs **in parallel**, so wall-clock time ≈ time of one job, not the sum.

---

## Prerequisites

- A GitHub repository (public or private)
- The workflow file committed under `.github/workflows/ci.yml`
- No secrets or external services required

---

## Steps

```bash
# 1 — Clone your repo and navigate to the lab
git clone https://github.com/<YOUR_USERNAME>/docker-cicd-labs.git
cd docker-cicd-labs

# 2 — Copy the lab files into the repo
cp -r /path/to/lab-02-matrix-lint github-actions/lab-02-matrix-lint

# 3 — Run quality checks locally before pushing (optional but recommended)
cd github-actions/lab-02-matrix-lint
pip install -r requirements.txt

# Lint — should produce no output if the code is clean
flake8 app/

# Format check — should print "All done! ✨ 🍰 ✨" with no reformatted files
black --check app/

# Tests
pytest --tb=short -v

# 4 — Commit and push to trigger the workflow
cd ../..
git add github-actions/lab-02-matrix-lint
git commit -m "feat(matrix-lint): add lab 02 — matrix strategy and lint gates"
git push origin main

# 5 — Watch the run
#   GitHub → your repo → Actions → "CI — Matrix & Lint"
#   You will see:
#     • 1 "Lint & Format check" job
#     • 2 "Test / Python X.Y" jobs running in parallel
#     • 1 "All tests passed" summary job
```

### Experiment: trigger a lint failure

```bash
# Add an unused import to calculator.py
echo "import os" >> github-actions/lab-02-matrix-lint/app/calculator.py

git add .
git commit -m "chore: intentional lint failure for demo"
git push

# The "lint" job fails on flake8 → matrix jobs are never started
# Revert:
git revert HEAD --no-edit
git push
```

### Experiment: trigger a format failure

```bash
# Break formatting manually
python3 -c "
import pathlib
p = pathlib.Path('github-actions/lab-02-matrix-lint/app/calculator.py')
p.write_text(p.read_text().replace('def add', 'def add   '))
"

git add .
git commit -m "chore: intentional format failure for demo"
git push

# The "lint" job fails on black --check → matrix jobs are never started
# Revert:
git revert HEAD --no-edit
git push
```

### Experiment: observe fail-fast behaviour

```bash
# In ci.yml, temporarily set fail-fast: true
# Then break a test only for Python 3.10 by adding a version guard:
#   import sys
#   if sys.version_info < (3, 11):
#       raise AssertionError("forced failure on 3.10")
# Push and watch — GitHub cancels the 3.11 job as soon as 3.10 fails.
```

---

## Comprehension checkpoints

1. **Why does the `lint` job run before the matrix?**
   Because lint failures are cheap to detect and would waste two parallel compute slots. The `needs: lint` gate ensures the matrix only starts when the code is clean.

2. **What is the difference between `fail-fast: true` and `fail-fast: false`?**
   With `true`, the first failing combination cancels all siblings — fast feedback, fewer wasted minutes. With `false`, all combinations run to completion — useful when you need to compare failure modes across versions.

3. **Why does each matrix leg have its own pip cache key?**
   Because Python 3.10 and 3.11 may produce different wheel binaries. Mixing caches would cause subtle installation errors.

4. **What does `black --check` actually do?**
   It formats the code in memory, diffs the result against the file on disk, and exits 1 if there is any difference. It never writes to disk in `--check` mode.

5. **What is `all-tests-passed` for?**
   Branch-protection rules require you to name specific required status checks. Listing every matrix combination (`Test / Python 3.10`, `Test / Python 3.11`, …) is fragile — adding a new version breaks the rule. A single summary job that `needs` all matrix legs is the standard solution.

---

## Useful links

- [GitHub Actions — Using a matrix](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/running-variations-of-jobs-in-a-workflow)
- [flake8 documentation](https://flake8.pycqa.org/en/latest/)
- [black documentation](https://black.readthedocs.io/en/stable/)
- [Caching dependencies — actions/cache](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/caching-dependencies-to-speed-up-workflows)
- [Defining concurrency](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/control-the-concurrency-of-workflows-and-jobs)