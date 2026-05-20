---
name: pr-db-review-overview
description: Create complete PR content overviews with special handling for database, schema, migration, ORM, seed, and data-model changes. Use when reviewing a PR, branch, or diff and the user asks for a PR overview, implementation overview, review summary, or database-change explanation, especially when changed files include migrations, SQL, drizzle/schema.ts, Prisma/schema files, ORM models, seed scripts, or database access code.
---

# PR DB Review Overview

## Diff Scope Rule

Always classify database changes relative to the PR review range, not relative to the
database's full migration history.

- "Added" means introduced by this PR's diff.
- "Changed" means modified by this PR's diff.
- "Removed" means dropped or deleted by this PR's diff.
- Tables or fields created by older migrations are existing context, even if they are new to the reviewer.
- Existing context may be shown in diagrams when it explains relationships, but it must not be highlighted as added unless the PR actually changes it.
- Before marking any table or field as added/changed/removed, verify it appears in `git diff <base>...HEAD`, not only in historical migration files.

## Workflow

1. Identify the review range before summarizing.
   - Prefer the PR base branch if known.
   - Otherwise inspect branch/remotes and use the merge-base against the likely base branch.
   - Collect `git status --short`, `git diff --stat`, `git diff --name-only`, and focused diffs for database-related files.

2. Build the PR overview from evidence, not assumptions.
   - Group changes by product area: app/UI, API/orchestrator, database, tests, infra, docs.
   - Mention the key files that prove each claim.
   - If the request is a review, keep findings/risks first, then summary.

3. Detect database changes broadly.
   Treat any of these as DB-relevant:
   - migration files, raw SQL, generated migration metadata
   - ORM schema/model files
   - seed/import/backfill scripts
   - query projections, storage types, row-level scope/privacy changes
   - indexes, constraints, foreign keys, generated columns, triggers, enums

4. Classify DB changes using the Diff Scope Rule.
   - Confirm added/changed/removed status from the review-range diff.
   - Treat pre-existing tables referenced by new FKs or queries as existing context.
   - Separate "schema changed in this PR" from "schema exists and is relevant context."

5. If DB changes exist, create a dedicated database overview section or artifact.
   Include:
   - Added, changed, and removed tables.
   - Added, changed, and removed columns/fields.
   - Indexes, unique constraints, checks, FKs, defaults, nullability, generated columns.
   - Migration order and whether rollout needs backfill, deploy ordering, or downtime care.
   - Readers/writers affected by the schema change.
   - Privacy, tenant-scope, or cross-session data exposure implications.
   - Verification performed and remaining test gaps.

## Visual DB Overview

When the user asks for a visual overview, HTML, diagram, map, or “make it easy to read”:

1. Create a temporary artifact under `tmp/`, usually `tmp/pr-db-overview.html` or a task-specific name.
2. Prefer an interactive UML/ER diagram with a detail panel:
   - Clicking a table explains what it stores, who writes it, who reads it, and why it exists.
   - Clicking a field explains its purpose, whether it is new/changed/removed, and any privacy or migration risk.
3. Use these visual conventions:
   - Added table/field in this PR: solid green border/fill.
   - Changed table/field in this PR: sky-blue accent.
   - Removed table/field in this PR: red dotted border/fill.
   - Existing context table/field: neutral styling, even if originally created by an older migration.
   - Privacy-sensitive path: amber callout.
4. Include zoom controls if the diagram can become dense.
5. Capture screenshots when iterating on readability or when the user asks to see what changed.

## Table And Field Detail Minimums

For every table highlighted as added/changed/removed in this PR, include rich detail. Do not stop at
one-line descriptions.

Table details should cover:

- Purpose: what real product or system behavior the table supports.
- Lifecycle: who creates rows, who updates rows, who deletes or archives rows.
- Readers: UI/API/agent jobs/cron paths that read the table.
- Writers: exact code paths or tools that insert/update rows.
- Relationships: FKs, parent/child tables, cascade behavior, and join keys.
- Constraints: PKs, unique indexes, checks, defaults, nullability, generated columns, and important normal indexes.
- Tenant/privacy model: tenant scoping, user scoping, public/private data boundary, and any cross-session exposure risk.
- Data shape: important JSONB shapes, enum values, example safe values, and high-cardinality fields.
- Migration/rollout: whether backfill is needed, whether existing rows are affected, deploy-order concerns, rollback impact.
- Operational notes: retention, cleanup, idempotency, failure/retry behavior, and monitoring implications.

Field details should cover:

- Type/nullability/default and whether it is added, changed, removed, or existing context.
- Semantic meaning: what business concept the field represents.
- Writers/readers: where the value comes from and who consumes it.
- Constraints/indexing: PK/FK/unique/check/index membership.
- Privacy/sensitivity: whether it contains user content, identifiers, secrets, private chat data, or tenant-scoped data.
- Migration behavior: default/backfill requirements and how legacy rows behave.
- Example value or JSON shape when helpful, using non-sensitive placeholders.

## Output Shape

For a normal PR overview, use this structure:

1. Executive summary.
2. What changed by area.
3. Database changes, if any.
4. Data/privacy implications.
5. Rollout and migration risks.
6. Verification.
7. Open questions.

For a code-review response, lead with findings ordered by severity, then include the overview only as supporting context.

If no database changes exist, say that explicitly and skip the visual DB artifact unless the user still asks for one.

## Quality Bar

- Cite concrete files and line numbers when available.
- Do not overstate runtime behavior that is not visible from the diff.
- Treat private data boundaries as first-class review surface.
- Check for destructive DDL, lock-heavy operations, generated columns, migration order problems, nullable/backfill issues, and unique constraints on dirty data.
- Keep generated artifacts temporary unless the user asks to commit them.
