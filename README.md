# Multi-Cloud Secure IaC

Secure-by-default infrastructure on **AWS and Azure**, provisioned with **Terraform**, configured with **Ansible**, and gated by an automated **DevSecOps pipeline**: nothing reaches `main` without passing SAST, IaC misconfiguration scanning and secret detection.

<!-- Replace with your real badges after the first green run -->
<!-- ![security-scan](https://github.com/Subash-1507/multicloud-secure-iac/actions/workflows/security-scan.yml/badge.svg) -->
<!-- [![Quality Gate](https://sonarcloud.io/api/project_badges/measure?project=Subash-1507_multicloud-secure-iac&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=Subash-1507_multicloud-secure-iac) -->

## Architecture

```
 developer ──► pre-commit (fmt, tflint, gitleaks, ansible-lint)
     │
     ▼ pull request
 GitHub Actions: security-scan.yml
 ├─ terraform fmt + TFLint ─────────── style, provider-specific mistakes
 ├─ terraform validate (per env) ───── syntax, types, module wiring
 ├─ Checkov ───────────────────────┐  Terraform, Ansible, workflow and secret checks
 ├─ Trivy config (tfsec successor) ┼─► SARIF ─► GitHub Security tab
 ├─ Gitleaks ──────────────────────┘  secrets anywhere in git history
 ├─ ansible-lint (production) ──────── playbook and role quality
 └─ SonarQube Cloud ────────────────── SAST + IaC rules, Quality Gate blocks merge
     │ all green + review
     ▼
 main ──► terraform plan/apply via OIDC (no stored cloud keys)

 AWS (ap-south-1)                          Azure (Central India)
 ├─ S3 data bucket                         ├─ Storage account
 │   SSE-KMS with customer-managed key     │   CMK in Key Vault, shared keys off
 │   TLS 1.2+ only, no public access       │   TLS 1.2+, no public blob access
 ├─ S3 access-log bucket                   ├─ Key Vault (RBAC, purge protection)
 └─ EC2 hardened by Ansible over SSM       └─ Linux VM hardened by Ansible
     (no inbound ports, no SSH keys)
```

## Security controls

| Control | AWS | Azure |
|---|---|---|
| Encryption at rest | SSE-KMS, customer-managed key, yearly rotation | Customer-managed key in Key Vault |
| Encryption in transit | Bucket policy denies non-TLS and TLS < 1.2 | `min_tls_version = TLS1_2`, HTTPS only |
| Public exposure | Block Public Access on, ACLs disabled | Public blob access off |
| Admin access | SSM Session Manager, no port 22 | Bastion / NSG allowlist |
| Host baseline | Ansible `baseline_hardening` role | Same role |
| CI credentials | GitHub OIDC to an IAM role | GitHub OIDC to an Entra ID app |
| State | S3 backend, encrypted, native locking | azurerm backend, Entra ID auth |

## Repository layout

```
.github/workflows/security-scan.yml   PR and main security gates
terraform/modules/<cloud>-<purpose>/  reusable, secure-by-default modules
terraform/envs/<cloud>-<env>/         thin root modules: backend, providers, module calls
ansible/roles/baseline_hardening/     OS hardening role (SSH, sysctl, auditd, ufw, updates)
ansible/inventories/dev/              dynamic inventories, no hardcoded IPs
docs/decisions/                       architecture decision records (ADRs)
```

## Getting started

Open the repo in **GitHub Codespaces** (Code → Codespaces → Create). The dev container installs Terraform, TFLint, Checkov, Trivy, ansible-lint and pre-commit, then run every CI gate locally:

```bash
make scan
```

To deploy the dev environment:

```bash
cd terraform/envs/aws-dev
cp backend.hcl.example backend.hcl && cp terraform.tfvars.example terraform.tfvars
terraform init -backend-config=backend.hcl
terraform plan
```

## Suppression policy

Scanner findings are fixed, not hidden. When a check genuinely does not apply, it is suppressed **inline, next to the resource, with a reason**, for example:

```hcl
# checkov:skip=CKV_AWS_145: S3 server access log delivery requires SSE-S3 on the target bucket
```

Every suppression is reviewed in the pull request like any other code.
