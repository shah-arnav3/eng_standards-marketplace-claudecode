# Azure Service Selection Reference

## Compute
- **Azure Functions** — event-driven, consumption or premium plan depending on cold-start tolerance.
- **Azure Container Apps** — default for containerized microservices needing autoscaling without full Kubernetes.
- **AKS** — only when you need Kubernetes-native tooling or multi-cloud portability.
- **Azure VMs + VM Scale Sets** — last resort, same rationale as any provider: avoid unless a specific OS-level requirement forces it.

## Storage and data
- **Blob Storage** for objects; lifecycle management policies to move cool/archive tiers automatically.
- **Azure SQL Database / Azure Database for PostgreSQL/MySQL** for relational workloads — prefer the flexible server tier for control over maintenance windows.
- **Cosmos DB** for globally distributed, low-latency NoSQL; choose the consistency level deliberately (session is the right default for most apps, not the extremes).
- **Azure Cache for Redis** for caching/ephemeral state.

## Messaging
- **Service Bus** for enterprise messaging with queues/topics, sessions, and dead-lettering.
- **Event Grid** for event-driven routing between Azure services and custom topics.
- **Event Hubs** for high-throughput streaming ingestion (Kafka-compatible endpoint available).

## Identity and access (Entra ID + RBAC)
- Managed identities (system- or user-assigned) attached to compute instead of storing client secrets.
- Azure RBAC scoped at the resource group or resource level, not subscription-wide, for anything beyond platform-team roles.
- Conditional Access policies enforced at the Entra ID tenant level for human identities.

```json
{
  "properties": {
    "roleName": "CheckoutServiceReader",
    "assignableScopes": ["/subscriptions/{sub}/resourceGroups/checkout-rg"],
    "permissions": [
      { "actions": ["Microsoft.Storage/storageAccounts/blobServices/containers/read"] }
    ]
  }
}
```

## Networking
- Virtual network per environment; subnets segmented by tier (app, data, management).
- Private Endpoints for PaaS services (Storage, SQL, Key Vault) instead of exposing them over the public endpoint.
- Network Security Groups scoped to application security groups where possible, rather than raw IP ranges.

## Infra as code
- Bicep (native, concise) or Terraform (provider-agnostic). Prefer Bicep for pure-Azure estates to get first-class what-if deployment previews.
