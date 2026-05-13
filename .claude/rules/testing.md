---
description: Test conventions for phel-pdo (phel.test + sqlite::memory:)
globs: tests/**
---

# Tests

- Single file: `tests/pdo_test.phel`
- `(use-fixtures :each db-fixture)` binds `*conn*` to a fresh `sqlite::memory:` connection per `deftest`
- Reuse `create-t1` / `insert-name` / `seed-t1`; only add new fixture helpers when a new schema is needed
- One `deftest` per behaviour; share setup via `testing` blocks
- Test names describe behaviour (`commit-persists-changes`, `fetch-returns-nil-when-no-rows`)
- Section comments (`;; ----`) group related tests
- PDO errors: wrap the failing call in `(try ... (catch \PDOException _e nil))`, then assert via `pdo/error-code` / `pdo/error-info`
- Run: `composer test` (the Phel test runner has no `--filter`; narrow by editing tests or using a scratch file)
- Do not introduce phpunit, rector, cs-fixer, or phpstan — this project is Phel-only by design
