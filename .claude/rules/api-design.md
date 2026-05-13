---
description: Public API shape rules for phel.pdo wrappers
globs: src/**
---

# API Design

phel-pdo is a thin idiomatic wrapper. Callers should never need to write `php/->` themselves.

- One Phel function per exposed PDO method. Name = kebab-case (`lastInsertId` → `last-insert-id`).
- First arg is the wrapped struct (`conn` / `stmt`), then PDO args in PHP order, then `& [optional]`.
- Optional args default inside the body via `(or x \PDO/DEFAULT)`, not via overloads.
- Mutators (`execute`, `bind-value`, `set-attribute`) return the wrapped struct so they thread with `->`.
- Reads (`fetch`, `fetch-all`, `fetch-column`, `row-count`, …) return Phel-native data.
- Rows out: route every raw fetch through `row->map` so keys become keywords.
- Params in: run user maps/vectors through `phel->php` before handing them to PDO.
- Errors: rely on `ERRMODE_EXCEPTION` (set in `connect`); don't re-wrap `\PDOException`.
- Don't expose raw `\PDO` / `\PDOStatement` from a public function.

## Adding a wrapper

1. Confirm it isn't already wrapped.
2. Remove it from the "Not implemented yet" block in `statement.phel` / `pdo.phel`.
3. Add the `defn` next to its peers.
4. Add a `deftest` in the matching section of `tests/pdo_test.phel`, driven through `*conn*` and `t1` where possible.
5. Update the API table in `README.md` and `## [Unreleased]` in `CHANGELOG.md`.
