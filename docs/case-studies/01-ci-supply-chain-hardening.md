# Case study: hardening the tool supply chain of a DevSecOps pipeline

**Project:** [multicloud-secure-iac](https://github.com/Subash-1507/multicloud-secure-iac) · **Pull request:** [#1](https://github.com/Subash-1507/multicloud-secure-iac/pull/1) · **Date:** October 2026

> **TL;DR:** A green security dashboard was hiding real issues. I found why, fixed the root cause, and hardened how every security tool in the pipeline is installed: pinned versions, SHA-256 hash verification, no install scripts, HTTPS-only downloads. The SonarQube Cloud security rating on new code went from **C to A**, with all **10 CI checks** passing on a protected branch.

## Results at a glance

| | Before | After |
|---|---|---|
| SonarQube Cloud security rating (new code) | C | **A** |
| Open security issues on the PR | 1 (plus 4 hidden) | **0** |
| How tool versions are chosen | "Whatever is newest today" | **Every package pinned and SHA-256 verified** |
| Third-party install scripts run during setup | Possible | **Blocked** (`--only-binary :all:`) |
| Direct pushes to `main` | Allowed | **Blocked**: PR plus 7 required checks |
| Dependency vulnerability scanning (SCA) | None | **Enabled** via lock files |

## The pipeline

Every pull request into `main` must pass these gates before it can merge:

```
pre-commit (local) ─► fmt · validate · TFLint · Gitleaks · ansible-lint
pull request ──────► Terraform fmt + TFLint
                     Terraform validate
                     Checkov ─────────┐
                     Trivy ───────────┴─► GitHub Security tab (SARIF)
                     Gitleaks
                     ansible-lint (production profile)
                     SonarQube Cloud ──► Quality Gate blocks the merge
```

## 1. Finding: a green dashboard was hiding unscanned code

SonarQube Cloud's first automatic scan reported 5 security issues, 4 of them in `.github/workflows/` and `.devcontainer/`. After switching to CI-based analysis, those 4 issues showed as **"Fixed"**, but nobody had changed those files.

**Root cause:** the scanner config only listed `terraform,ansible` as sources. The CI workflow and dev-container scripts had silently dropped out of scope, and SonarQube closes issues in files it no longer analyzes.

**Why it matters:** CI pipelines hold tokens and push code, so they are part of the attack surface. I added `.github` and `.devcontainer` back to the analysis scope.

## 2. The real issues, and how I fixed them

| Finding | Risk | Fix |
|---|---|---|
| `pip install` without `--only-binary :all:` | A source package runs its `setup.py` during install: arbitrary code execution on the CI runner | Wheel-only installs, so no third-party build script ever runs |
| Unpinned tool versions | A bad or hijacked release enters the pipeline automatically | Exact versions in `requirements-*.in` |
| Dependencies not locked to *verified* versions | Indirect dependencies still float, and nothing proves the downloaded file is the one I tested | `pip-compile --generate-hashes` lock files plus `pip install --require-hashes`: every file is checked against its SHA-256 |
| `wget` follows redirects | A redirect could silently downgrade a download | `curl --proto '=https' --proto-redir '=https' --tlsv1.2` |
| File readable by "others" (`0644`) | Possible data exposure (CWE-732) | **Accepted with a written reason:** Debian's default for `apt.conf.d`, contains no secrets, and stricter modes break `apt` for non-root users |

Not every finding is a fix. Some are a documented decision. Every exception in this repo is written down next to the code, with its reason.

## 3. Problems I hit along the way, and solved properly

- **Ansible silently ignored its config file.** In Codespaces the repo folder was world-writable, and Ansible refuses to load `ansible.cfg` from such folders so an attacker can't plant one. I removed the insecure permission (`chmod -R o-w`) instead of working around the check, and made the fix permanent in the dev-container setup.
- **A pre-commit hook couldn't find the role.** The hook runs from the repo root, where the config isn't read. I moved the playbook next to `roles/`, the standard Ansible layout, so roles resolve from any directory.
- **A tooling mismatch blocked commits.** The ansible-lint hook expected Python 3.14 and the dev container has 3.12. I pinned the hook's Python version.
- **A YAML parsing trap.** A shell command containing `:all: ` broke the workflow, because `: ` means key/value in YAML. Quoting the command fixed it, and I added a YAML parse check before committing.
- **Dependency conflicts in a shared environment.** Installing one tool upgraded a library another tool needed. I isolated the lock tool in its own virtualenv and restored the environment from the lock file.

## 4. How I verified it

- `make scan` runs the same six gates locally: Terraform fmt, validate, TFLint, Checkov, Trivy and ansible-lint all pass.
- A **clean, empty virtualenv** installs the full tool chain with `--require-hashes --only-binary :all:`.
- All pre-commit hooks pass.
- **10/10 CI checks pass** on [PR #1](https://github.com/Subash-1507/multicloud-secure-iac/pull/1), and the SonarQube Quality Gate passed with **0 new issues**.
- `main` is protected by a ruleset: no direct pushes, no force pushes, all 7 gates required.

## 5. Skills demonstrated

**DevSecOps:** shift-left security, CI security gates, SAST (SonarQube Cloud), IaC scanning (Checkov, Trivy), secret scanning (Gitleaks), SARIF and GitHub code scanning
**Supply-chain security:** pinned and hash-verified dependencies, wheel-only installs, GitHub Actions pinned to commit SHAs, Dependabot
**Platform:** GitHub Actions, branch rulesets, Codespaces dev containers, pre-commit, Terraform, Ansible, Linux permissions
**Engineering judgement:** root-cause analysis, separating real risk from false positives, documenting accepted risk

## What's next

- Triage the 4 dependency risks SonarQube found once the lock files made them visible
- Move the scanners into their own virtualenv to remove a shared-library conflict
- Deploy the AWS module (S3 with a customer-managed KMS key) and add the Azure side, using GitHub OIDC so CI holds no long-lived cloud keys
