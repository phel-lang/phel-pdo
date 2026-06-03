# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `pdo/insert` - build an `INSERT` from a map (`(pdo/insert conn :table {:col v ...})`), execute it as a prepared statement, and return the new `last-insert-id`. Identifiers must match `[A-Za-z_][A-Za-z0-9_]*` ([#4]).
- `pdo/bind-param` - wrap `PDOStatement::bindParam`; binds a parameter applied at execution time ([#8]).
- `pdo/close-cursor` - wrap `PDOStatement::closeCursor`; frees the cursor so the statement can be re-executed ([#9]).
- `pdo/fetch-object` - wrap `PDOStatement::fetchObject`; returns the next row as an object (`stdClass` or a named class), or `nil` when exhausted ([#11]).
- `pdo/set-fetch-mode` - wrap `PDOStatement::setFetchMode`; sets the statement's default fetch mode, with mode-specific extra args ([#13]).
- `pdo/column-meta` - wrap `PDOStatement::getColumnMeta`; returns a 0-indexed column's metadata as a map, or `nil` when unavailable ([#15]).
- `pdo/statement-seq` - expose a statement's rows as a lazy seq of maps (the Phel-idiomatic take on `PDOStatement::getIterator`), so callers can `map`/`reduce`/`take` without materialising the whole result set ([#16]).
- `pdo/next-rowset` - wrap `PDOStatement::nextRowset`; advances a multi-rowset statement (e.g. stored procedures on MySQL/Postgres) ([#17]).
- `pdo/with-transaction` macro - runs a body in a transaction, committing on success (returning the last body value) and rolling back + re-throwing on error; runs inline when already in a transaction ([#20]).
- `pdo/from-connection` - wrap an already-open `\PDO` (e.g. a Symfony/Doctrine DBAL connection) as a phel-pdo connection, reusing the host's handle as-is; `{:apply-defaults true}` opts into `ERRMODE_EXCEPTION` ([#21]).

### Changed

- `pdo/get-attribute` / `pdo/set-attribute` now dispatch on the handle: pass a connection (as before) or a statement to reach `PDOStatement::getAttribute` / `setAttribute` ([#12]).
- `pdo/error-code` / `pdo/error-info` now dispatch on the handle: pass a statement to read `PDOStatement::errorCode` / `errorInfo` ([#14]).

## [0.1.0] - 2026-05-13

### Changed

- Upgrade required phel-lang to `^0.37`.
- Merge `statement.phel` into the single `phel.pdo` namespace; statement functions are now reached as `pdo/fetch`, `pdo/execute`, etc.
- Restructure tests into a single `tests/pdo_test.phel` with shared fixtures.
- Adopt phel 0.37 idioms: `^bool` tag on `set-attribute`, `for :pairs` + `into` in `row->map`, `when-let` in `fetch`.
- `pdo/fetch` returns `nil` (instead of an empty map) when no rows remain.
- Rewrite README: tighter intro, table-based API reference, threaded examples via `->`.

### Removed

- Optional `phel-config.php` (no special config needed).
- `Dockerfile` and `compose.yaml` (library installs via composer; no Docker needed for dev).

## [0.0.8] - 2025-06-09

### Fixed

- Rename `keyowrd` → `keyword` ([#2], thanks @jasalt).
- Doc: note about return value of `statement/execute` ([#3]).
- Require correct `phel-lang` version.

## [0.0.7] - 2024-06-24

### Changed

- Support `phel-lang` 0.15.

## [0.0.6] - 2024-06-24

### Changed

- Support `phel-lang` >= 0.14 (includes 0.15).

## [0.0.5] - 2024-05-25

### Fixed

- `Cannot resolve symbol 'pdo/connect'` error; add `phel-config.php` ([#1]).

## [0.0.4] - 2024-05-25

### Changed

- Packagist package name changed from `smeghead/phel-pdo` to `phel-lang/phel-pdo`.
- Update `phel-lang` to v0.14.1.

## [0.0.3] - 2024-05-23

### Added

- Statement `bind-value`.
- Statement `debug-dump-params`.

## [0.0.2] - 2024-05-17

### Changed

- README note about migration to the `phel-lang` organization.
- Move `statement.phel` directly under `src/`.

## [0.0.1] - 2024-05-02

### Added

- Initial PDO method coverage.

## [0.0.0] - 2024-04-23

### Added

- Minimum functionality.
