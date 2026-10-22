# Multi-Cloud Secure IaC

[![security-scan](https://github.com/Subash-1507/multicloud-secure-iac/actions/workflows/security-scan.yml/badge.svg)](https://github.com/Subash-1507/multicloud-secure-iac/actions/workflows/security-scan.yml)
[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=Subash-1507_multicloud-secure-iac&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=Subash-1507_multicloud-secure-iac)
[![Security Rating](https://sonarcloud.io/api/project_badges/measure?project=Subash-1507_multicloud-secure-iac&metric=security_rating)](https://sonarcloud.io/summary/new_code?id=Subash-1507_multicloud-secure-iac)

Secure-by-default infrastructure as code for **Azure and AWS**, written in **Terraform** and gated by an automated **DevSecOps pipeline**. Nothing reaches `main` without passing SAST, IaC misconfiguration scanning, secret detection and linting, and nothing reaches Azure without my approval. The Azure environment was **deployed and verified end to end**, then **torn down** in October 2026 to save cloud credits; the evidence below is from the live deployment. The deploy pipeline holds **no stored cloud credentials**.

> 📄 **Case study:** [How I hardened this pipeline's tool supply chain](docs/case-studies/01-ci-supply-chain-hardening.md): SonarQube security rating C → A, hash-verified dependencies, 10/10 CI gates.

## Highlights

- **Keyless deploys:** GitHub Actions signs in to Azure with OIDC. There is no client secret, and the trust rules match GitHub's immutable subject (owner and repo IDs).
- **The pipeline cannot change its own access:** CI identities live in a separate resource group that only a human applies.
- **No privilege escalation:** the deploy identity may grant only two Key Vault roles, enforced by an Azure ABAC condition.
- **Approval gate:** every apply waits for my review in the `azure-dev` environment, runs only from `main`, and admin bypass is off.
- **Just-in-time network access:** the Key Vault and storage firewalls deny everything. CI opens them for the runner's IP and always closes them, even when the apply fails.
- **Customer-managed encryption:** an RSA-3072 key in Key Vault with RBAC, purge protection and auto-rotation encrypts a zone-redundant storage account that has shared keys disabled.
- **Secured supply chain:** Actions pinned to commit SHAs, Python tools hash-locked, and every accepted risk documented next to the code.

## How it works

**1. Every change goes through the security pipeline before it can reach `main`:**

```mermaid
flowchart LR
  dev["Developer<br/>(Codespaces)"] --> pc["pre-commit<br/>local gates"]
  pc --> pr["Pull request"]
  pr --> gates["7 required checks<br/>─────────────<br/>Terraform fmt + TFLint<br/>Terraform validate<br/>Checkov · Trivy<br/>Gitleaks · ansible-lint<br/>SonarQube Quality Gate"]
  gates -->|"all green"| main["main<br/>(protected)"]
  gates -.->|"findings"| sec["GitHub Security tab<br/>triaged with reasons"]
  main --> apply["terraform apply<br/>(GitHub OIDC,<br/>after my approval)"]
```

**2. What is deployed on Azure, and how the pieces trust each other:**

```mermaid
flowchart LR
  tf["Terraform"] -->|"Entra ID auth<br/>Blob Data Contributor<br/>(state container only)"| state[("Remote state<br/>shared keys off<br/>versioning")]
  tf -->|"Crypto Officer<br/>(this vault only)"| kv["Key Vault<br/>RBAC · purge protection<br/>firewall deny<br/>just-in-time IP"]
  kv --- key["cmk-storage<br/>RSA-3072<br/>wrap/unwrap only<br/>auto-rotates"]
  sa[("Storage account<br/>CMK · ZRS<br/>double encryption<br/>no shared keys<br/>firewall deny<br/>just-in-time IP")] -->|"authenticates as"| mi["Managed identity"]
  mi -->|"Encryption User<br/>(this key only)"| key
  tf -->|"creates"| sa
```

**3. How GitHub Actions signs in to Azure: no secrets, and nothing deploys without approval:**

```mermaid
flowchart LR
  pr["Pull request"] -->|"OIDC token<br/>subject: pull_request"| plan["id-msi-gha-plan<br/>Reader on the RG<br/>state container only"]
  main["main + my approval<br/>(azure-dev environment)"] -->|"OIDC token<br/>subject: environment:azure-dev"| apply["id-msi-gha-apply<br/>Contributor on the RG<br/>RBAC Admin, ABAC-limited"]
  apply -->|"may grant only"| roles["Key Vault Crypto Officer<br/>Crypto Service Encryption User"]
  apply -.->|"blocked by ABAC"| owner["Owner / any other role"]
  ci["rg-msi-ci<br/>identities + trust rules<br/>human-applied only"] -.-|"defines"| plan
  ci -.-|"defines"| apply
```

The AWS module (S3 + KMS customer-managed key) is written and scanned; deploying it is blocked by the AWS account's Organizations SCP.

## Status

The project is **complete** for its current scope. Items marked *Future work* are designed or partly written, but not deployed.

| Part | State |
|---|---|
| CI security gates (7 required checks, protected `main`) | ✅ Done |
| Hash-locked tool supply chain | ✅ Done ([case study](docs/case-studies/01-ci-supply-chain-hardening.md)) |
| Codespaces dev container with `make scan` | ✅ Done |
| Azure dev environment (resource group, remote state with Entra ID auth, no keys) | ✅ Deployed and verified · torn down |
| Azure Key Vault + customer-managed key (RBAC, purge protection, firewall, auto-rotation) | ✅ Deployed and verified · torn down |
| Azure storage account encrypted with the customer-managed key (ZRS, double encryption, no shared keys, firewall) | ✅ Deployed and verified · torn down |
| GitHub OIDC identities in their own resource group, ABAC-limited role delegation | ✅ Deployed and verified · torn down |
| Just-in-time firewall access (`scripts/azure-firewall-ip.sh`) | ✅ Done |
| GitHub Actions deploys: plan on every PR, apply on `main` after my approval | ✅ Ran successfully · workflow disabled after teardown |
| AWS secure storage module (S3 + customer-managed KMS key) | ✅ Written and scanned · ⛔ deploy blocked by the account's AWS Organizations SCP |
| Ansible `baseline_hardening` role (SSH, sysctl, auditd, ufw, automatic updates) | ✅ Written and linted · 🗓️ Future work: run on a host |
| Linux VM hardened by Ansible; AWS EC2 over SSM | 🗓️ Future work |

## Evidence

**Every security gate passes locally before code is pushed** (`make scan`):

![make scan running Terraform validate, TFLint, Checkov](docs/images/01-make-scan.png)
![Trivy finds 0 misconfigurations in both environments; ansible-lint passes; all gates pass](docs/images/02-scan-summary.png)

**SonarQube Cloud Quality Gate: passed, security rating A.** The one counted issue is an accepted, documented risk (`0644` on an apt config file):

![SonarQube Cloud project health: Quality Gate passed, security rating A](docs/images/03-sonarqube-gate.png)

**Control plane vs data plane on Azure.** As subscription Owner I could create the state container but not read it, until I granted *Storage Blob Data Contributor* scoped to that single container:

![Owner is denied blob access: data-plane permission required](docs/images/04-data-plane-denied.png)
![After the container-scoped role assignment: data-plane access works](docs/images/05-data-plane-ok.png)

**Hardened Terraform state storage:** account keys and anonymous blob access disabled, HTTPS only, TLS 1.2 minimum:

![Storage account configuration: key access and anonymous access disabled, secure transfer required](docs/images/06-storage-hardening.png)
![Storage account minimum TLS version 1.2](docs/images/07-storage-tls.png)

**Key Vault holding a customer-managed key**, deployed with Terraform: RBAC permission model, purge protection, firewall denying everything except one IP, and an RSA-3072 key limited to wrap/unwrap:

![terraform apply: Key Vault, role assignment and key created](docs/images/08-kv-apply.png)
![Key is non-exportable RSA-3072, recoverable, with a one-year expiry matching Terraform state](docs/images/09-kv-key-attributes.png)
![Key Vault Crypto Officer granted to the Terraform identity, scoped to this vault only](docs/images/10-kv-rbac.png)
![Key Vault properties: Standard tier, soft delete 7 days, purge protection enabled and irreversible](docs/images/11-kv-properties.png)

**Checkov blocked the new storage account with 5 findings.** I fixed one (LRS to ZRS) and recorded four as accepted risk, not applicable or false positive, plus geo-replication accepted for data residency:

![Checkov: 5 failed checks on the storage account, make scan blocked](docs/images/12-storage-checkov-findings.png)
![After decisions: 0 failed checks, all security gates pass](docs/images/13-storage-checkov-resolved.png)

**Storage encrypted with my customer-managed key** (envelope encryption): key source Key Vault, the versionless key resolved to the current version, infrastructure encryption on, zone-redundant, shared keys disabled, firewall Deny:

![Storage account encryption: keySource Microsoft.Keyvault with cmk-storage, ZRS, shared key access disabled](docs/images/14-storage-cmk-encryption.png)

**First approval-gated deploy from GitHub Actions.** The merge to `main` waited for my approval; then the job signed in to Azure with OIDC (no stored secret), opened the firewalls for the runner's IP only, and ran `terraform plan` and `apply`:

![Deployment approved; Terraform apply job: Azure OIDC login, just-in-time firewall opened, init and plan succeeded](docs/images/15-ci-approved-apply.png)

**The firewall closes again every time**, even if the apply fails, and the runner's Azure session is cleared:

![Close firewalls step succeeded; post-job az account clear](docs/images/16-ci-firewall-closed.png)

## How a change reaches `main`

```
 developer ──► pre-commit (fmt, validate, TFLint, Gitleaks, ansible-lint)
     │
     ▼ pull request (direct pushes to main are blocked)
 GitHub Actions: security-scan.yml
 ├─ Terraform fmt + TFLint ─────────── style, provider-specific mistakes
 ├─ Terraform validate (per env) ───── syntax, types, module wiring
 ├─ Checkov ───────────────────────┐  Terraform, Ansible, workflow and secret checks
 ├─ Trivy config (tfsec successor) ┴─► SARIF ─► GitHub Security tab
 ├─ Gitleaks ───────────────────────── secrets anywhere in git history
 ├─ ansible-lint (production) ──────── playbook and role quality
 └─ SonarQube Cloud ────────────────── SAST + IaC rules + dependency risks; Quality Gate blocks merge
     │ all 7 green
     ▼
 main ──► terraform-azure.yml: apply after my approval (GitHub OIDC, no stored cloud keys)
```

## Architecture

```
 Azure (Southeast Asia) · deployed, then torn down  AWS (ap-south-1) · written and scanned
 ├─ rg-msi-dev  (workload, deployed by CI)        ├─ S3 data bucket
 │   ├─ Key Vault: RBAC, purge protection,        │   SSE-KMS, customer-managed key
 │   │   firewall deny, just-in-time IP           │   TLS 1.2+ only, no public access
 │   ├─ cmk-storage: RSA-3072, auto-rotates       └─ S3 access-log bucket
 │   └─ Storage account: CMK, ZRS, double
 │       encryption, no shared keys, firewall deny
 ├─ rg-msi-ci   (CI identities, human-applied only)
 │   ├─ id-msi-gha-plan   (pull requests, read-only)
 │   └─ id-msi-gha-apply  (approved main runs, ABAC-limited)
 └─ rg-msi-tfstate (Terraform state, Entra ID auth, shared keys off)
```

## Security controls

| Control | AWS | Azure |
|---|---|---|
| Encryption at rest | SSE-KMS, customer-managed key, yearly rotation | Customer-managed key in Key Vault |
| Encryption in transit | Bucket policy denies non-TLS and TLS < 1.2 | `min_tls_version = TLS1_2`, HTTPS only |
| Public exposure | Block Public Access on, ACLs disabled | Public blob access off |
| Host access *(future work)* | SSM Session Manager, no port 22 ([ADR 0001](docs/decisions/0001-ssm-instead-of-ssh.md)) | Just-in-time SSH from one IP, keys only |
| Host baseline *(future work)* | Ansible `baseline_hardening` role | Same role |
| Deploy approval | n/a | `azure-dev` environment: required reviewer, `main` only, no admin bypass |
| CI credentials | GitHub OIDC to an IAM role | GitHub OIDC to user-assigned managed identities (federated credentials, no secrets) |
| Network access to secrets | n/a | Key Vault and storage firewalls default Deny; IPs added just in time, never in code |
| State | S3 backend, encrypted, native locking | azurerm backend, Entra ID auth |

## CI access to Azure (GitHub OIDC)

GitHub Actions never holds an Azure secret. Each run gets a short-lived token from GitHub, and Azure accepts it only if its **subject** matches a federated credential:

| Identity | Who can use it | What it can do |
|---|---|---|
| `id-msi-gha-plan` | Pull requests (`repo:…:pull_request`) | Read the resource group; read and lock the state blob. Cannot change anything. |
| `id-msi-gha-apply` | Only the `azure-dev` environment (`repo:…:environment:azure-dev`), which requires my approval and runs only from `main` | Manage resources in one resource group; grant **only** the two Key Vault roles |

**Why the apply identity cannot escalate:** Terraform must create the Key Vault role assignments, so the identity has *Role Based Access Control Administrator*. On its own, that role could grant itself Owner. An **ABAC condition** limits it to assigning or removing *Key Vault Crypto Officer* and *Key Vault Crypto Service Encryption User*. Every other role is denied by Azure itself. *Contributor* cannot grant roles, so the identity's reach stays inside one resource group, behind an approval.

**Why the pipeline cannot change its own access:** both identities, their trust rules and their role assignments live in a separate resource group, `rg-msi-ci`, managed by its own Terraform root (`terraform/envs/azure-ci`) with its own state. Only a human applies that root. CI has no role on `rg-msi-ci`, so even an approved pipeline run cannot add a trust rule or widen its own permissions.

**Just-in-time network access:** the Key Vault and the storage account deny all networks. Terraform ignores their IP lists, so no IP is ever committed. `scripts/azure-firewall-ip.sh` adds the caller's current IP before work and removes it after (`add`, `remove`, `reset`, `list`). The CI apply job does the same: it adds the runner's IP, applies, and always removes it, even on failure.

**Immutable OIDC subject:** this repository's tokens carry GitHub's immutable subject (`repo:<owner>@<owner-id>/<repo>@<repo-id>:…`), and the trust rules match it. A renamed or re-created repository with the same name gets a different ID, so it cannot reuse the trust.

**Accepted risk, documented inline:** SonarQube rule S6381 flags the *Contributor* assignment. It is scoped to one resource group, usable only from the approval-gated environment, and cannot be used to grant roles. The decision sits next to the code as a `NOSONAR` comment with its reason.

## Known limitations and accepted risks

Recorded here so the trade-offs are explicit:

| Item | Why it is accepted | What would change it |
|---|---|---|
| The state storage account accepts any network | Every request still needs Entra ID and a data-plane role on the one container, and shared keys are off. GitHub-hosted runners have changing IPs. | Self-hosted runners or private endpoints |
| PR plans run with `-refresh=false` | The read-only plan identity cannot (and should not) open the firewalls, so PR plans compare code with saved state. The apply job does a full refresh. | A scheduled drift-detection run with the apply identity |
| I approve my own deployments | Solo project. | In a team: a second required reviewer and *Prevent self-review* |
| *Contributor* on the workload resource group | Scoped to one resource group, behind the approval gate; role grants are ABAC-limited. | Narrow built-in roles per resource type |
| Zone-redundant (ZRS), not geo-redundant, storage | Dev data with no cross-region recovery requirement; documented inline as a Checkov skip. | GZRS for production |

## Future work

- **Linux VM hardened by Ansible:** Trusted Launch VM, no password login, just-in-time SSH, then the existing `baseline_hardening` role, measured with a **Lynis hardening index before and after**, plus an idempotency check (`changed=0` on the second run).
- **Guardrail tests:** a workflow that *attacks* the controls and expects failure: a PR token trying the apply identity, the apply identity trying to grant itself Owner, editing its own trust rule, and checking that the firewall is closed after every run.
- **AWS deployment** of the S3 + KMS module once the account's Organizations SCP allows it.

## Pipeline supply-chain security

The tools that check the code are secured too:

- **GitHub Actions pinned to commit SHAs**, not tags; Dependabot proposes updates.
- **Python tools hash-locked:** `requirements-*.in` lists what we need, and `pip-compile --generate-hashes` produces `requirements-*.txt` with every package pinned and SHA-256 verified.
- **Installs use `--require-hashes --only-binary :all:`**, so no tampered file and no third-party `setup.py` can run.
- **Downloads are HTTPS-only with TLS 1.2+**, and redirects can't downgrade them.
- **Least-privilege workflow permissions:** read-only by default, write only where a job uploads results.

## Repository layout

```
.github/workflows/security-scan.yml   PR and main security gates
.github/workflows/terraform-azure.yml Azure deploys: plan on PRs, approval-gated apply on main
.github/dependabot.yml                weekly updates for Actions, Terraform and pip
.devcontainer/                        Codespaces environment with every scanner installed
terraform/modules/<cloud>-<purpose>/  reusable, secure-by-default modules
terraform/envs/<cloud>-<env>/         thin root modules: backend, providers, module calls
terraform/envs/azure-ci/              CI identities for GitHub OIDC; applied by a human only
ansible/harden.yml                    playbook: applies baseline_hardening to all hosts
ansible/roles/baseline_hardening/     OS hardening role (SSH, sysctl, auditd, ufw, updates)
ansible/inventories/dev/              dynamic inventories, no hardcoded IPs
requirements-*.in / requirements-*.txt  tool versions / hash-locked lock files
docs/case-studies/                    write-ups of real problems and how they were solved
docs/decisions/                       architecture decision records (ADRs)
scripts/azure-firewall-ip.sh          just-in-time firewall access for the dev Key Vault and storage
Makefile                              `make scan` runs every CI gate locally
```

## Getting started

Open the repo in **GitHub Codespaces** (Code → Codespaces → Create codespace on main). The dev container installs Terraform, TFLint, Checkov, Trivy, ansible-lint and pre-commit. Then run every CI gate locally:

```bash
make scan
```

To work on a change:

```bash
git switch -c feature/my-change
# edit, then
make scan
git commit -am "Describe the change"   # pre-commit runs the local gates
git push -u origin feature/my-change
gh pr create
```

### Updating tool versions

Edit the `.in` file, then regenerate its lock file:

```bash
pip-compile --generate-hashes --allow-unsafe --output-file requirements-ci.txt requirements-ci.in
pip-compile --generate-hashes --allow-unsafe --output-file requirements-dev.txt requirements-dev.in
```

### Deploying the Azure dev environment

> **Current state:** all Azure resources were deleted after the project was verified, and the `terraform-azure` workflow is disabled. To redeploy: bootstrap the state storage account, apply `terraform/envs/azure-ci` (human only), update the client-ID secrets, apply `azure-dev`, then re-enable the workflow.

**Normal path:** open a pull request. The **Terraform plan (azure-dev)** check shows what would change. Merge it, approve the `azure-dev` deployment, and the pipeline applies it.

**Manual path** (from Codespaces, for the human-only `azure-ci` root or emergencies):

```bash
az login
scripts/azure-firewall-ip.sh reset      # allow only your current IP, just in time
cd terraform/envs/azure-dev
cp backend.hcl.example backend.hcl && cp terraform.tfvars.example terraform.tfvars   # fill in; both are git-ignored
terraform init -backend-config=backend.hcl
terraform plan -out=dev.tfplan          # review: nothing should be destroyed
terraform apply dev.tfplan && rm dev.tfplan
../../../scripts/azure-firewall-ip.sh remove
```

The AWS dev environment is written and validated, but its deployment is blocked by the account's Organizations SCP.

## Suppression policy

Scanner findings are fixed, not hidden. When a check genuinely does not apply, it is suppressed **inline, next to the code, with a reason**, for example:

```hcl
# checkov:skip=CKV_AWS_145: S3 server access log delivery requires SSE-S3 on the target bucket
role_definition_name = "Contributor" # NOSONAR(terraform:S6381): one RG, approval-gated env only; ...
```

Every suppression is reviewed in the pull request like any other code.

## Author

**Subash Chandra Bose**: DevOps, Cloud & Security Engineer · Microsoft Certified (SC-500, AZ-104, SC-200)
[Portfolio](https://subash-1507.github.io) · [LinkedIn](https://www.linkedin.com/in/subash-chandra-bose-014bb21b5) · [GitHub](https://github.com/Subash-1507)
