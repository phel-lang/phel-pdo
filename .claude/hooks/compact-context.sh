#!/bin/bash
# SessionStart hook: re-inject key context after compaction
cat <<'EOF'
## Context Reminder (post-compaction)

**phel-pdo** is a thin PDO wrapper in pure Phel. Single namespace `phel.pdo`. Two structs: `connection {:pdo}` and `statement {:stmt}`.

- Conventional commits (`feat:`, `fix:`, `ref:`, `chore:`, `docs:`, `test:`, `ci:`). NEVER mention AI tooling.
- Test: `composer test` (runs `vendor/bin/phel test`).
- Format: `.phel` edits auto-format via PostToolUse hook (`vendor/bin/phel format`).
- Layout: `src/pdo.phel` (connection-side) + `src/pdo/statement.phel` (statement-side, `(in-ns phel.pdo)`). Single test file `tests/pdo_test.phel` with `*conn*` + `seed-t1` fixtures.
- API design: mutators return the wrapped struct so callers can thread; reads return Phel data via `row->map`; never expose raw `\PDO`/`\PDOStatement`.
- CHANGELOG (Keep a Changelog): update `## [Unreleased]` for user-facing changes.
- Release: `./release.sh <X.Y.Z>`.
- Protected: `release.sh`, `.github/*`, `composer.lock`.
EOF
