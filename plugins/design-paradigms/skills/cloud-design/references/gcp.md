# Google Cloud Service Selection Reference

## Compute
- **Cloud Run** — default for containerized, request-driven services; scales to zero, no cluster to manage.
- **Cloud Functions** — lightweight event-driven glue code; prefer Cloud Run for anything beyond a single-purpose trigger handler.
- **GKE (Autopilot by default, Standard when you need node-level control)** — only when Kubernetes-native tooling is required.
- **Compute Engine** — last resort; use Managed Instance Groups with autoscaling, never a standalone unmanaged VM in production.

## Storage and data
- **Cloud Storage** for objects; configure lifecycle rules for storage class transitions (Standard to Nearline/Coldline/Archive).
- **Cloud SQL** for managed relational (Postgres/MySQL); **AlloyDB** for Postgres-compatible workloads needing higher performance.
- **Firestore** for document-model NoSQL with strong client SDK support; **Bigtable** for very high-throughput wide-column workloads.
- **Memorystore (Redis)** for caching.
- **BigQuery** for analytical/warehouse workloads — never as an OLTP substitute.

## Messaging
- **Pub/Sub** for both point-to-point and fan-out messaging — a single service covers what SQS+SNS split into two on AWS.
- **Eventarc** for routing events from Google services and custom sources to compute triggers.

## IAM
- IAM bound at the smallest scope that works (project > folder > organization only when a policy genuinely applies broadly).
- Service accounts attached to workloads via Workload Identity (GKE) or attached service accounts (Cloud Run/Functions) — never downloaded JSON key files in application code.
- Custom roles built from predefined role permissions when a predefined role is too broad, rather than granting `roles/editor`/`roles/owner`.

```yaml
bindings:
  - role: roles/storage.objectViewer
    members:
      - serviceAccount:checkout-service@my-project.iam.gserviceaccount.com
    condition:
      title: "uploads-prefix-only"
      expression: "resource.name.startsWith('projects/_/buckets/my-bucket/objects/uploads/')"
```

## Networking
- VPC per environment (or shared VPC for centrally managed networking across projects), private (non-default) subnets for workloads.
- Private Google Access / Private Service Connect for reaching managed services without a public IP.
- Firewall rules scoped by service account or network tag, not broad CIDR ranges, for internal traffic.

## Infra as code
- Terraform (dominant for GCP) or Deployment Manager (legacy, avoid for new work).
