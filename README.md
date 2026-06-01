# Project Bedrock — InnovateMart EKS Deployment

AltSchool Cloud Engineering Karatu 2025 Capstone Project.

## Overview

Production-grade microservices deployment on AWS EKS for InnovateMart Inc.

| Resource | Value |
|---|---|
| AWS Region | us-east-1 |
| EKS Cluster | project-bedrock-cluster |
| App Namespace | retail-app |
| Assets Bucket | bedrock-assets-alt-soe-025-3783 |
| Lambda | bedrock-asset-processor |

## Prerequisites

- AWS CLI v2 configured with admin credentials
- Terraform >= 1.5
- kubectl
- Helm >= 3.x
- Git

## Step 1 — Bootstrap (one-time)

```bash
chmod +x scripts/bootstrap.sh
./scripts/bootstrap.sh
```

This creates the S3 state bucket and DynamoDB lock table.

## Step 2 — Clone the Retail Store App

```bash
git submodule update --init --recursive
# OR manually:
git clone https://github.com/aws-containers/retail-store-sample-app.git helm/retail-store-sample-app
```

Then build Helm dependencies:

```bash
helm dependency build helm/retail-store-sample-app/src/app/chart
```

## Step 3 — Configure GitHub Secrets

Update `terraform.tfvars` with your GitHub username **before the first apply** — this is required to create the OIDC role for CI/CD:

```hcl
github_org  = "your-github-username"   # REQUIRED for CI/CD OIDC to work
github_repo = "project-bedrock"
domain_name = ""                       # optional — set a registered domain to enable Bonus 5.2 TLS
```

After first apply, add this secret in your GitHub repo settings → Secrets and variables → Actions:

| Secret | Value |
|---|---|
| `AWS_ROLE_ARN` | `terraform output github_actions_role_arn` |

## Step 4 — First Deploy (local)

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

> **EKS version**: deployed on **v1.35** (≥ v1.34 as required). Check available
> versions with `aws eks describe-cluster-versions --region us-east-1` and update
> `eks_version` in `terraform.tfvars` if needed.

## Step 5 — CI/CD Pipeline

- **Create a PR** targeting `main` → triggers `terraform plan` → plan output posted as PR comment
- **Merge to main** → triggers `terraform apply` → `grading.json` auto-committed to repo root

## Step 6 — Access the Application

```bash
# Update kubeconfig
aws eks update-kubeconfig --name project-bedrock-cluster --region us-east-1

# Get the app URL (also available in Terraform outputs)
terraform -chdir=terraform output app_url

# OR directly via kubectl
kubectl get ingress -n retail-app -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'
```

Open the URL in your browser. It may take 2–3 minutes after deploy for the ALB to become healthy.

## Step 7 — Verify Developer Access

```bash
# Configure bedrock-dev-view credentials
export AWS_ACCESS_KEY_ID=$(terraform -chdir=terraform output -raw bedrock_dev_view_access_key_id)
export AWS_SECRET_ACCESS_KEY=$(terraform -chdir=terraform output -raw bedrock_dev_view_secret_access_key)
aws eks update-kubeconfig --name project-bedrock-cluster --region us-east-1

# Should succeed:
kubectl get pods -n retail-app

# Should fail (Forbidden):
kubectl delete pod -n retail-app $(kubectl get pods -n retail-app -o jsonpath='{.items[0].metadata.name}')
```

## Helm Deployment (Bonus 5.1)

The upstream retail-store-sample-app Helm chart is **committed to this repo** under
[`helm/chart/`](helm/chart/), and a custom values file that overrides the data layer
to point at RDS / DynamoDB is at [`helm/values-override.yaml`](helm/values-override.yaml).

Deploy or upgrade the retail store app with a single command:

```bash
# build the subchart dependencies once
helm dependency build helm/chart/app/chart

# single-command deploy/upgrade
helm upgrade --install retail-store helm/chart/app/chart \
  --namespace retail-app \
  --create-namespace \
  -f helm/values-override.yaml
```

> Note: Terraform also manages this deployment via the `helm_release` resource
> (pointing at the same committed chart), so a normal `terraform apply` deploys
> the app automatically. The command above is for manual deploys / testing.

## Bonus 5.2 — TLS/DNS (supported, not enabled on this deployment)

> **Status:** Not enabled. This AWS account is Free-Tier, which blocks Route53
> domain registration, and a publicly-trusted ACM certificate cannot be issued
> for a domain you do not control (ACM requires DNS/email validation of an owned
> domain). The application is therefore exposed over **HTTP** via the ALB.
>
> The Terraform code already **supports** TLS end-to-end — it is gated behind the
> `domain_name` variable. To enable genuine trusted HTTPS, register a domain,
> create a Route53 hosted zone for it, then set in `terraform.tfvars`:
>
> ```hcl
> domain_name = "your-registered-domain.com"
> ```
>
> On the next `terraform apply`, the [`iam` module](terraform/modules/iam/route53.tf)
> will:
> 1. Request a DNS-validated ACM certificate for the domain (+ `*.domain`)
> 2. Create the Route53 validation records and wait for issuance
> 3. Create an A/ALIAS record pointing the domain at the ALB
> 4. Attach the cert to the ALB via the ingress annotations
>    (`certificate-arn`, `listen-ports [80,443]`, `ssl-redirect 443`), terminating
>    TLS at the ALB and redirecting HTTP → HTTPS.

## Generate grading.json

```bash
cd terraform
terraform output -json > ../grading.json
```

This is auto-generated by the CI/CD pipeline on every merge to main.

## Cost Controls

| Action | Command |
|---|---|
| Scale down nodes | `aws eks update-nodegroup-config --cluster-name project-bedrock-cluster --nodegroup-name project-bedrock-nodes --scaling-config desiredSize=0 minSize=0 maxSize=4 --region us-east-1` |
| Stop RDS MySQL | AWS Console → RDS → project-bedrock-mysql → Stop |
| Stop RDS PostgreSQL | AWS Console → RDS → project-bedrock-postgres → Stop |
| Delete ALB (stop charges) | `kubectl delete ingress retail-store-ingress -n retail-app` |

Estimated costs: ~$4/day idle, ~$15/day active.

## Architecture

See [docs/architecture-diagram.png](docs/architecture-diagram.png).
