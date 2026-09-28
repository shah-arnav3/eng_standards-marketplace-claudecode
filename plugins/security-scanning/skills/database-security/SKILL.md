---
name: database-security
description: Database-layer security vulnerability scanning — access control and least privilege, encryption at rest, backup security, audit logging, and data minimization/PII handling. Use whenever reviewing database configuration, access grants, encryption settings, or the user mentions database security, data protection, or PII handling.
---

# Database Security Vulnerability Scanning

## Access control and least privilege

- Application database users get only the privileges their workload needs — a service that only ever reads and writes rows should not have `DROP`/`ALTER`/`CREATE ROLE` privileges, and a read-only reporting job should have a read-only user, not the same credential as the write path.
- Separate credentials per service/environment — never one shared database user across every microservice and every environment (dev/staging/prod), which makes both blast-radius containment and audit attribution impossible.
- No direct human access to production databases as a matter of routine — access through a reviewed, logged access path (a bastion, a temporary elevated-privilege grant with expiry) rather than a standing personal login.

```sql
-- Least-privilege application role, not a superuser/owner credential
CREATE ROLE checkout_app LOGIN PASSWORD '...';
GRANT SELECT, INSERT, UPDATE ON orders, order_items TO checkout_app;
-- No DELETE if the service never deletes; no DDL privileges at all.
```

## Encryption at rest and in transit

- Encryption at rest enabled at the storage/volume layer at minimum (most managed database services enable this by default — verify, don't assume); column-level encryption for the most sensitive fields (payment details, government ID numbers) as an additional layer.
- TLS required for all client connections to the database, not optional/best-effort — reject plaintext connections at the database configuration level, not just by convention in the client.
- Key management through a managed KMS with rotation, not a static key embedded in application configuration.

## Backup security

- Backups encrypted with the same rigor as the live database — a backup is a full copy of the sensitive data, and is frequently the weaker link (older retention policies, broader access grants, sometimes stored in a less-monitored location).
- Access to backups restricted and audited separately from access to the live database — someone who can read a backup can read every record in the database at whatever point in time it was taken.
- Test restoration regularly — an untested backup is not a verified backup, and this is also the point where access-control gaps in the restore path tend to surface.

## Audit logging

- Log access to sensitive tables/rows (who queried what, when) separately from general application logs, with tamper-evident storage (write-once, shipped to a separate system the application itself can't modify).
- Alert on anomalous access patterns: a service account suddenly reading far more rows than its normal workload, an off-hours bulk export, access from an unexpected network location.
- Retain audit logs for the period required by applicable compliance obligations for the data involved (e.g., financial or health data often carries specific retention requirements) — confirm the actual requirement rather than assuming a default.

## Data minimization and PII handling

- Collect and retain only the fields actually needed for the product to function — every additional stored field is additional breach exposure with no offsetting benefit if it's never used.
- Mask/tokenize sensitive fields in non-production environments (staging, local dev, analytics) — a production data dump copied into staging "for testing" is a very common real-world exposure path.
- Define and enforce a retention/deletion policy for PII rather than retaining it indefinitely by default — data that's been deleted per policy cannot be breached.

```sql
-- Masking sensitive columns in a non-production copy
UPDATE customers_staging
SET email = 'user' || id || '@example.test',
    phone = NULL,
    ssn_last4 = '0000';
```

## Injection defense (database-specific)

- Parameterized queries/prepared statements exclusively for any query built with user input — see the `backend-security` skill for the application-layer half of this; the database configuration side is ensuring the application's database user has no more privilege than the queries it's meant to run actually require, limiting the damage even if an injection bypass occurs.
- Disable or restrict dangerous built-in functions/procedures not needed by the application (e.g., `xp_cmdshell` in SQL Server, unrestricted file-read/write functions) at the database configuration level.

## Quick scan checklist

- [ ] Application database users scoped to least privilege, not shared or superuser-level
- [ ] No routine standing human access to production databases
- [ ] Encryption at rest verified (not assumed) and TLS required for connections
- [ ] Backups encrypted, access-restricted, and restoration tested periodically
- [ ] Audit logging on sensitive tables, shipped to a system the application can't tamper with
- [ ] PII minimized, masked in non-production environments, and covered by a retention/deletion policy
- [ ] Dangerous database built-ins disabled/restricted if unused by the application
