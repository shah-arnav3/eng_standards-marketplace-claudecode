# AWS Service Selection Reference

## Compute
- **Lambda** — event-driven, sub-15-minute executions, scales to zero. Default for glue code, API backends behind API Gateway, stream processors.
- **ECS Fargate** — containerized workloads without managing EC2 instances; default container choice unless you need Kubernetes-specific tooling.
- **EKS** — only when you need Kubernetes portability, existing K8s tooling, or third-party operators that assume it.
- **EC2** — last resort; use Auto Scaling Groups + Launch Templates, never a hand-configured standalone instance in production.

## Storage and data
- **S3** for objects/blobs; enable versioning + lifecycle rules to transition to Glacier for cold data.
- **RDS/Aurora** for relational; Aurora Serverless v2 for spiky/unpredictable relational workloads.
- **DynamoDB** for key-value/single-table NoSQL at scale; design the partition key around access patterns up front, not after.
- **ElastiCache (Redis)** for caching and ephemeral state, never as a primary datastore.

## Messaging
- **SQS** for point-to-point durable queues; **SNS** for fan-out pub/sub; **EventBridge** for event-bus routing between decoupled services/SaaS integrations.
- **Kinesis** or **MSK (Kafka)** only when you need ordered, replayable streaming at high throughput — not as a default queue replacement.

## IAM
- IAM roles with least-privilege policies attached to compute (instance profiles / task roles / Lambda execution roles) — never embedded access keys.
- Service control policies (SCPs) at the AWS Organizations level for guardrails (deny regions, deny root user actions) that no account can override.
- Permission boundaries for any role that can create other roles.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject"],
      "Resource": "arn:aws:s3:::my-app-bucket/uploads/*",
      "Condition": { "StringEquals": { "aws:PrincipalTag/team": "checkout" } }
    }
  ]
}
```

## Networking
- VPC per environment, private subnets for compute, public subnets only for load balancers/NAT gateways.
- VPC endpoints (Gateway for S3/DynamoDB, Interface for other services) to avoid routing AWS-internal traffic over the public internet.
- Security groups scoped to specific source security groups, not CIDR ranges, wherever the source is another AWS resource.

## Infra as code
- Terraform (provider-agnostic) or AWS CDK/CloudFormation (native, better drift detection with CloudFormation).
