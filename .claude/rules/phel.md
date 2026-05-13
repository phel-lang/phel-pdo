---
description: Phel conventions + test layout for phel-pdo
globs: src/**,tests/**
---

# Phel Conventions

## Naming

- kebab-case for symbols: `last-insert-id`, `row->map`, `seed-t1`.
- `defn-` / `def-` for private (not exported).
- Namespace `phel.pdo`. `src/pdo/statement.phel` starts with `(in-ns phel.pdo)`.
- Test namespace: `phel.pdo-test`.

## Docstrings

Public functions get a terse `:doc` one-liner as the first form after the param vector — match the existing style in `src/pdo.phel` / `src/pdo/statement.phel` ("Initiates a transaction", "Fetches the next row from a result set, or nil if no more rows").

Return-type tags (`^bool`, `^int`, `^string`) reflect the underlying PDO return type, not the wrapper's container.

## Comments

- `;` inline, `;;` standalone, `;;; ` section header.
- `#| |#` multiline, `#_` to comment out a form.
- Keep the "Not implemented yet" block at the bottom of `statement.phel` in sync when wrapping new PDO methods.

## Semantics

- Prefer `into`, `for :pairs`, `when-let`, threading (`->`, `->>`).
- `defstruct` for wrapped handles (`connection`, `statement`); fields are plain keywords.
- PDO interop: always `(php/-> (x :pdo) (method ...))` / `(php/-> (x :stmt) (method ...))`. Cross the boundary with `phel->php` / `php->phel`.
- PDO constants: `\PDO/FETCH_ASSOC`, `\PDO/PARAM_STR`, `\PDO/ATTR_ERRMODE`, …

## Multi-file namespace

`src/pdo.phel` ends with `(load "pdo/statement")`. New cross-file decls go via `declare` in `src/pdo.phel` before the `load`.

## Tests (`tests/pdo_test.phel`)

```phel
(ns phel.pdo-test
  (:require phel.test :refer [deftest is testing use-fixtures])
  (:require phel.pdo))

(deftest <descriptive-name>
  (seed-t1 *conn*)
  (is (= <expected> (pdo/<fn> *conn* ...))))
```

Rules:

- `(use-fixtures :each db-fixture)` binds `*conn*` to a fresh `sqlite::memory:` per `deftest`.
- One behaviour per `deftest`; share setup via `testing` blocks.
- Reuse `create-t1` / `insert-name` / `seed-t1`; only build new tables for a new schema.
- For PDO errors: `(try ... (catch \PDOException _e nil))` then assert `pdo/error-code` / `pdo/error-info`.
- Section comments (`;; ----`) group related tests.
- Run: `composer test` (full) or `vendor/bin/phel test tests/pdo_test.phel` (explicit).
- The Phel runner has no `--filter`; narrow by editing tests or using a scratch file.
