---
name: cloud-design
description: Modern cloud-native architecture across AWS, Azure, and Google Cloud — well-architected framework pillars, service selection (compute, storage, messaging), infrastructure as code, and multi-account/project isolation. Use whenever designing cloud infrastructure, choosing between managed services, writing Terraform/CloudFormation/Bicep, or the user mentions AWS, Azure, GCP, serverless, or cloud architecture. Read the matching reference file (aws.md, azure.md, or gcp.md) for provider-specific service choices.
---

# Cloud Architecture Design (AWS / Azure / GCP)

Cloud design is provider-agnostic at the principle level and provider-specific at the service level. Apply the shared framework below first, then load the reference file for whichever provider(s) the task involves.

## Shared design pillars (map to AWS Well-Architected / Azure Well-Architected / Google Cloud Architecture Framework)

1. **Operational excellence** — infrastructure as code for everything; no manual console changes to anything running in production.
2. **Security** — least-privilege IAM, encryption in transit and at rest by default, no long-lived credentials where a managed identity/role will do.
3. **Reliability** — design for the failure of any single component; define RTO/RPO explicitly before choosing a multi-region strategy.
4. **Performance efficiency** — right-size compute, prefer managed/serverless services over self-managed infrastructure unless a specific requirement rules them out.
5. **Cost optimization** — tag everything for cost attribution, choose the pricing model (on-demand vs. reserved/committed vs. spot) deliberately, and treat idle resources as a cost bug.

## Infrastructure as code — mandatory, provider-agnostic

Every resource is defined in Terraform, Pulumi, or the provider-native tool (CloudFormation/CDK, Bicep/ARM, Deployment Manager) and reviewed like application code. Rules:

- No `ClickOps` — if it's not in version control, it doesn't exist for audit/reproducibility purposes.
- Separate state per environment (dev/staging/prod), never a shared mutable state file across environments.
- Modules/stacks parameterized by environment, not copy-pasted per environment.

```hcl
# Terraform — a reusable module invoked per environment, not duplicated
module "api_service" {
  source      = "./modules/api-service"
  environment = var.environment
  instance_count = var.environment == "prod" ? 3 : 1
  tags = {
    Environment = var.environment
    Owner       = "platform-team"
    CostCenter  = "eng-backend"
  }
}
```

## Account/project isolation

- Separate accounts (AWS Organizations) / subscriptions (Azure) / projects (GCP) per environment and per major workload boundary — blast radius containment, not just convention.
- Centralize identity (AWS IAM Identity Center / Azure Entra ID / Google Cloud Identity) rather than per-account local users.
- A landing-zone/hub-and-spoke network model for anything beyond a single small workload: shared networking/security services in a hub, workloads isolated in spokes.

## Choosing compute: the same decision tree across providers

1. **Event-driven, short-lived, bursty** → serverless functions (Lambda / Azure Functions / Cloud Functions or Cloud Run).
2. **Long-running, containerized, need orchestration** → managed Kubernetes (EKS / AKS / GKE) or a simpler managed container service (ECS Fargate / Azure Container Apps / Cloud Run) if you don't need full Kubernetes.
3. **Legacy/lift-and-shift, stateful, needs OS-level control** → managed VMs (EC2 / Azure VMs / Compute Engine) with auto-scaling groups, as a last resort rather than a default.

Default to the most managed option that meets the requirement — every layer of infrastructure you self-manage is a layer you must patch, scale, and secure yourself.

## Data and messaging

- Durable async communication between services → a managed queue/topic (SQS/SNS, Azure Service Bus/Event Grid, Pub/Sub) instead of direct synchronous service-to-service calls for anything that doesn't need an immediate response.
- Object storage (S3 / Blob Storage / Cloud Storage) for anything unstructured/large; never store large blobs directly in a relational database.
- Managed relational/NoSQL databases over self-hosted database VMs unless a specific extension/version requirement forces it.

## Reference files — read the one(s) relevant to the task

- `references/aws.md` — AWS service selection, IAM patterns, networking
- `references/azure.md` — Azure service selection, RBAC, networking
- `references/gcp.md` — GCP service selection, IAM, networking

Load only the reference(s) needed for the current task; each is self-contained and assumes the shared principles above.

## Common pitfalls (all providers)

- Hardcoded credentials/API keys in code or CI config instead of a managed identity, secrets manager, or workload identity federation.
- A single security group / NSG / firewall rule allowing `0.0.0.0/0` on a management port (SSH/RDP) — always restrict to a bastion, VPN, or IP allowlist.
- No tagging strategy, making cost attribution and cleanup of orphaned resources impossible after a few months.
- Treating multi-region as free — it multiplies operational complexity and cost; justify it against an actual RTO/RPO requirement, not "just in case."
- Provisioning resources manually "temporarily" and never converting them to IaC.
