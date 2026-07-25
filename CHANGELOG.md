# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Breaking changes

- **`pdo/fetch-column` returns `nil` on an exhausted cursor**, not PHP's `false` sentinel, matching `pdo/fetch` and every other reader. It also gained a `not-found` argument - `(pdo/fetch-column stmt 0 :eof)` - because a SQL `NULL` column is `nil` too, and the two were previously indistinguishable. Internally it now reads through `fetch(FETCH_NUM)` rather than `fetchColumn`, so a column holding a real boolean `false` (Postgres `bool`) is no longer mistaken for end-of-rows. *Migration:* replace `(= false (pdo/fetch-column s))` with `(nil? ...)`, or pass a sentinel ([#35]).

### Fixed

- Passing something that is not a connection or statement to `pdo/get-attribute`, `pdo/set-attribute`, `pdo/error-code` or `pdo/error-info` now raises an `InvalidArgumentException` naming what was expected, instead of an opaque PHP `Error` from inside PDO. The connection-only and statement-only wrappers are guarded the same way, and handing a raw `\PDO` to any of them points you at `pdo/from-connection` ([#36]).

## [0.2.0] - 2026-07-25

### Breaking changes

Three call-site changes since `0.1.0`. Each corrects behaviour that was wrong, not
merely different - check these before upgrading.

- **`pdo/error-code` returns a string.** It used to run the SQLSTATE through
  `php/intval`, which corrupted every non-numeric state: `"HY000"` became `0`. Any
  code branching on the old integer was silently taking the wrong branch.
  `pdo/error-info`'s first element changes the same way (`driver-code` stays an int).
  *Migration:* compare against the string - `(= "HY000" (pdo/error-code conn))`.
- **`pdo/last-insert-id` and `pdo/insert` return a string.** PDO reports the id as a
  string; returning it verbatim is lossless for big integers and named sequences.
  *Migration:* `(php/intval (pdo/last-insert-id conn))` where you need a number.
- **`pdo/get-available-drivers` takes no connection argument.**
  `PDO::getAvailableDrivers` is static, so requiring a connection was wrong.
  *Migration:* drop the argument - `(pdo/get-available-drivers)`.

### Added

- `pdo/insert` - build an `INSERT` from a map and return the new `last-insert-id`; identifiers must match `[A-Za-z_][A-Za-z0-9_]*` ([#4]).
- `pdo/bind-param` - bind a parameter applied at execution time ([#8]).
- `pdo/close-cursor` - free the cursor so the statement can be re-executed ([#9]).
- `pdo/fetch-object` - next row as an object (`stdClass` or a named class), or `nil` when exhausted ([#11]).
- `pdo/set-fetch-mode` - set the statement's default fetch mode, with mode-specific extra args ([#13]).
- `pdo/column-meta` - a 0-indexed column's metadata as a map, or `nil` when unavailable ([#15]).
- `pdo/statement-seq` - the remaining rows as a lazy seq of maps, so callers can `map`/`reduce`/`take` without materialising the whole result set ([#16]).
- `pdo/next-rowset` - advance a multi-rowset statement (e.g. stored procedures) ([#17]).
- `pdo/with-transaction` macro - run a body in a transaction (commit + return last value, or rollback + re-throw); runs inline when already in a transaction ([#20]).
- `pdo/from-connection` - wrap an already-open `\PDO` (e.g. a framework/DBAL connection) as-is; `{:apply-defaults true}` opts into `ERRMODE_EXCEPTION` ([#21]).

### Changed

- `pdo/get-attribute` / `pdo/set-attribute` now accept a connection **or** a statement handle ([#12]).
- `pdo/error-code` / `pdo/error-info` now accept a connection **or** a statement handle ([#14]).

The three BC entries for this release are listed under **Breaking changes** above.

### Fixed

- `pdo/connect` / `pdo/prepare` now accept an options map with integer `\PDO/ATTR_*` keys (previously raised a `TypeError`).
- `pdo/bind-value` / `pdo/bind-param` now keep an integer `column` as a 1-based positional index, fixing positional (`?`) binding.
- `pdo/insert` rejects an empty `row` map with an `InvalidArgumentException` instead of generating invalid SQL.
- `pdo/set-fetch-mode` throws an `InvalidArgumentException` on too many extra args instead of silently doing nothing.

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

[Unreleased]: https://github.com/phel-lang/phel-pdo/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/phel-lang/phel-pdo/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/phel-lang/phel-pdo/compare/v0.0.8...v0.1.0
[0.0.8]: https://github.com/phel-lang/phel-pdo/compare/v0.0.7...v0.0.8
[0.0.7]: https://github.com/phel-lang/phel-pdo/compare/v0.0.6...v0.0.7
[0.0.6]: https://github.com/phel-lang/phel-pdo/compare/v0.0.5...v0.0.6
[0.0.5]: https://github.com/phel-lang/phel-pdo/compare/v0.0.4...v0.0.5
[0.0.4]: https://github.com/phel-lang/phel-pdo/compare/v0.0.3...v0.0.4
[0.0.3]: https://github.com/phel-lang/phel-pdo/compare/v0.0.2...v0.0.3
[0.0.2]: https://github.com/phel-lang/phel-pdo/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/phel-lang/phel-pdo/compare/v0.0.0...v0.0.1
[0.0.0]: https://github.com/phel-lang/phel-pdo/releases/tag/v0.0.0

[#1]: https://github.com/phel-lang/phel-pdo/issues/1
[#2]: https://github.com/phel-lang/phel-pdo/issues/2
[#3]: https://github.com/phel-lang/phel-pdo/issues/3
[#4]: https://github.com/phel-lang/phel-pdo/issues/4
[#8]: https://github.com/phel-lang/phel-pdo/issues/8
[#9]: https://github.com/phel-lang/phel-pdo/issues/9
[#11]: https://github.com/phel-lang/phel-pdo/issues/11
[#12]: https://github.com/phel-lang/phel-pdo/issues/12
[#13]: https://github.com/phel-lang/phel-pdo/issues/13
[#14]: https://github.com/phel-lang/phel-pdo/issues/14
[#15]: https://github.com/phel-lang/phel-pdo/issues/15
[#16]: https://github.com/phel-lang/phel-pdo/issues/16
[#17]: https://github.com/phel-lang/phel-pdo/issues/17
[#20]: https://github.com/phel-lang/phel-pdo/issues/20
[#21]: https://github.com/phel-lang/phel-pdo/issues/21
[#35]: https://github.com/phel-lang/phel-pdo/issues/35
[#36]: https://github.com/phel-lang/phel-pdo/issues/36
