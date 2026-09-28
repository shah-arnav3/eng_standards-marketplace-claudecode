---
name: sql-design
description: Modern relational database design — normalization vs. deliberate denormalization, indexing strategy, transaction isolation levels, query design, and schema migration practices. Use whenever designing a database schema, writing or reviewing SQL queries, discussing indexes, transactions, migrations, or the user mentions Postgres, MySQL, SQL Server, or relational data modeling.
---

# SQL Database Design

Relational design is procedural in nature: get the schema and constraints right first, then let the query planner do the work. Most SQL performance and correctness problems trace back to schema decisions, not query syntax.

## Normalization — start at 3NF, denormalize deliberately

Default to Third Normal Form: every non-key column depends on the key, the whole key, and nothing but the key. This eliminates update anomalies by construction.

```sql
-- Normalized (3NF): no repeated group, no transitive dependency
CREATE TABLE customers (
    customer_id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    email       TEXT NOT NULL UNIQUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE orders (
    order_id    BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    customer_id BIGINT NOT NULL REFERENCES customers(customer_id),
    status      TEXT NOT NULL CHECK (status IN ('pending','paid','shipped','cancelled')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE order_items (
    order_id   BIGINT NOT NULL REFERENCES orders(order_id),
    product_id BIGINT NOT NULL REFERENCES products(product_id),
    quantity   INT NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(10,2) NOT NULL,
    PRIMARY KEY (order_id, product_id)
);
```

Denormalize (a cached total, a materialized view, a read-optimized reporting table) only after profiling shows normalized joins are the bottleneck, and always keep the denormalized value's source of truth clear (trigger, application code, or scheduled refresh — pick one, document it).

## Constraints do the validation work

Push invariants into the schema so they hold regardless of which application or script writes to the table:

- `NOT NULL` by default; nullable columns should be a deliberate exception.
- `CHECK` constraints for value ranges/enums instead of trusting application code.
- `FOREIGN KEY` with an explicit `ON DELETE` policy (`RESTRICT`, `CASCADE`, `SET NULL`) — never leave it implicit.
- `UNIQUE` constraints for business keys, not just the surrogate primary key.

## Indexing strategy

- Index every foreign key column — most engines do not do this automatically, and unindexed FKs cause slow deletes/updates on the parent table.
- Composite indexes: column order matters — put the equality-filtered column(s) first, range-filtered/sorted columns last, matching your most common `WHERE`/`ORDER BY` shape.
- Use `EXPLAIN ANALYZE` before adding an index, not intuition — confirm a sequential scan is actually the cost driver.
- Partial indexes for a common filtered query (`WHERE status = 'pending'`) instead of indexing the whole table.
- Every index has a write-cost trade-off; don't index columns that are never filtered/joined/sorted on.

```sql
CREATE INDEX idx_orders_customer_status ON orders (customer_id, status)
    WHERE status IN ('pending', 'paid');   -- partial index for the hot query path

EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE customer_id = 42 AND status = 'pending';
```

## Transactions and isolation

- Wrap multi-statement writes that must succeed or fail together in an explicit transaction; never rely on autocommit for a multi-step business operation.
- Default isolation (`READ COMMITTED` in Postgres/SQL Server, `REPEATABLE READ` in MySQL/InnoDB) is right for most OLTP work. Reach for `SERIALIZABLE` only for operations with genuine race conditions that lower isolation can't prevent (e.g., "check balance then debit" without row locking).
- Prefer explicit row locking (`SELECT ... FOR UPDATE`) over raising isolation level globally, so you pay the concurrency cost only where the race actually exists.

```sql
BEGIN;
SELECT balance FROM accounts WHERE account_id = 1 FOR UPDATE;
UPDATE accounts SET balance = balance - 100 WHERE account_id = 1;
UPDATE accounts SET balance = balance + 100 WHERE account_id = 2;
COMMIT;
```

- Keep transactions short — no network calls, no waiting on user input, inside an open transaction. A long-held transaction blocks other writers and bloats the WAL/undo log.

## Query design

- Select only the columns you need — never `SELECT *` in application code, since it breaks silently when columns are added/reordered and prevents covering indexes.
- Prefer `JOIN` over correlated subqueries for the same logical result; let the planner choose the join strategy.
- Use window functions (`ROW_NUMBER() OVER (...)`, `SUM(...) OVER (...)`) instead of self-joins or application-side aggregation for running totals, ranking, and deduplication.
- Paginate with keyset pagination (`WHERE id > :last_id ORDER BY id LIMIT 50`) instead of `OFFSET` for large tables — `OFFSET` re-scans and discards rows, degrading linearly with page depth.

```sql
-- Keyset pagination — constant-time regardless of how deep the user pages
SELECT * FROM orders
WHERE (created_at, order_id) < (:last_created_at, :last_order_id)
ORDER BY created_at DESC, order_id DESC
LIMIT 50;
```

## Migrations

- Every schema change is a versioned, forward-only migration file, applied through a migration tool (Flyway, Liquibase, Alembic, golang-migrate, EF Core Migrations) — never a manual `ALTER TABLE` run by hand against production.
- Additive-first for zero-downtime deploys: add a nullable column, backfill, then add `NOT NULL`/drop the old column in a later migration, so the old application version keeps working during rollout.
- Every migration should have a tested rollback path or be explicitly documented as irreversible (e.g., a destructive drop).

## Common pitfalls

- Using the natural key (email, SSN) as the primary key instead of a surrogate key — natural keys change, surrogate keys don't.
- `NULL` used to mean three different things in the same column ("unknown", "not applicable", "not yet set") — model them as distinct states if the distinction matters.
- N+1 query patterns from an ORM's lazy loading — eager-load or batch-fetch associated rows for any list view.
- Storing money as `FLOAT`/`DOUBLE` — always `NUMERIC`/`DECIMAL` with an explicit scale.
- Adding an index for every column "just in case" — this silently degrades write throughput and is rarely revisited.
