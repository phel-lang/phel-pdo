# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Breaking changes

- **`pdo/query` takes params as its second argument.** `(pdo/query conn sql [1])` and `(pdo/query conn sql {:id 1})` now bind through a prepared statement; previously the second argument was a fetch mode, so passing params raised a `TypeError`. The fetch mode moves to an options map. It was nearly inert there anyway - `pdo/fetch` and `pdo/fetch-all` request `FETCH_ASSOC` regardless, so it only ever affected native iteration. *Migration:* `(pdo/query conn sql \PDO/FETCH_NUM)` becomes `(pdo/query conn sql nil {:fetch-mode \PDO/FETCH_NUM})` ([#41]).
- **`pdo/fetch-column` returns `nil` on an exhausted cursor**, not PHP's `false` sentinel, matching `pdo/fetch` and every other reader. It also gained a `not-found` argument - `(pdo/fetch-column stmt 0 :eof)` - because a SQL `NULL` column is `nil` too, and the two were previously indistinguishable. Internally it now reads through `fetch(FETCH_NUM)` rather than `fetchColumn`, so a column holding a real boolean `false` (Postgres `bool`) is no longer mistaken for end-of-rows. *Migration:* replace `(= false (pdo/fetch-column s))` with `(nil? ...)`, or pass a sentinel ([#35]).

### Changed

- `pdo/fetch-all` and `pdo/statement-seq` compute the result set's column keywords once instead of re-keywording every cell of every row: **2.2x** and **2.5x** faster respectively on 20k rows x 5 columns (2002 ms -> 924 ms, 2090 ms -> 848 ms). No API change; rows come back identical. Drivers that cannot report column metadata fall back to the previous `FETCH_ASSOC` path. `bench/fetch_all.phel` reproduces the numbers ([#39]).

### Added

- `pdo/bind-column` and `pdo/fetch-bound` - the Phel counterpart of PDO's `FETCH_BOUND`. `bind-column` binds a result column (1-based position or name) to an atom and returns a new statement, so bindings thread with `->`; `fetch-bound` fetches the next row and resets every bound atom, returning `false` once exhausted. It does not delegate to `PDOStatement::bindColumn`: that binds a PHP variable by reference and Phel has no by-reference locals to give it. This completes the PDO surface - there is no longer a "not implemented yet" list ([#46]).
- `pdo/expand-in` - expands list-valued params into matching placeholder runs, returning `[sql params]` ready for `pdo/query` or `pdo/prepare`. `in (?)` with `[1 2 3]` becomes `in (?, ?, ?)`; named params expand to `:ids_0, :ids_1`. Binding a variable-length list is the one thing PDO genuinely cannot do, and the hand-rolled workaround means concatenating SQL. The scanner leaves `?` and `:name` inside string literals, quoted identifiers and comments alone, and does not mistake a Postgres `::` cast for a placeholder. An empty list and a param/placeholder count mismatch both raise ([#45]).
- `pdo/update`, `pdo/delete` and `pdo/insert-many` - the CRUD siblings `pdo/insert` was missing. All validate identifiers with the same `check-ident` rule and bind every value as a parameter. `update` prefixes its placeholders by clause (`:set_id` / `:where_id`) so `set id = ? where id = ?` binds two different values correctly. An empty `where` map raises rather than silently rewriting or emptying the whole table, and `insert-many` requires one shared key set across rows. `insert-many` returns an affected row count, not an id - that is driver-specific for multi-row inserts ([#43]).
- `pdo/select`, `pdo/select-one` and `pdo/select-value` - one-shot reads that go straight to rows. `select` returns every row (`[]` when none), `select-one` the first row or `nil`, `select-value` the first column of the first row with an optional `not-found` sentinel. All three bind params through a prepared statement and release the cursor before returning. `select` forwards options to `pdo/fetch-all`, so `{:as :rows}` works there too ([#42]).
- `pdo/fetch-all` takes an `:as` option to pick the row shape. `:maps` (the default, unchanged) gives a seq of maps; `:rows` gives `{:cols [...] :rows [[...]]}` for column-oriented work - **5x faster** on 20k rows x 5 columns (869 ms -> 172 ms), because it never builds a map per row. An unknown `:as` raises `InvalidArgumentException` rather than silently falling back ([#40]).
- `pdo/column-names` - the result set's column names as a vector of keywords in select order, or `nil` when the driver cannot report them ([#40]).
- `pdo/with-savepoint` - run a thunk inside a `SAVEPOINT`, releasing it on success or rolling back to it and re-throwing. The primitive behind nested `pdo/with-transaction` ([#37]).

### Fixed

- Params now bind with a PDO type inferred from the Phel value - `nil` as `PARAM_NULL`, booleans as `PARAM_BOOL`, integers as `PARAM_INT`, everything else as `PARAM_STR`. Everything previously defaulted to `PARAM_STR`, which native prepares mostly re-inferred but emulated prepares (PDO's MySQL default) did not: `limit :n` interpolated as `limit '10'`, a syntax error on MySQL, and `where id = '10'` defeated integer indexes. Applies to `pdo/bind-value`, `pdo/bind-param` and `pdo/execute` alike; an explicit `type` argument still wins. `pdo/execute` now binds each param individually, since handing the array to `PDOStatement::execute` forces `PARAM_STR` on every value ([#38]).
- Nested `pdo/with-transaction` now isolates rollbacks. It used to run the body inline, so a nested block that threw and was caught by the caller still had its writes committed by the outer transaction - a failed unit of work silently became durable. The nested case is now bracketed with a `SAVEPOINT`. An uncaught throw still propagates and rolls the outer transaction back, as before ([#37]).
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
[#37]: https://github.com/phel-lang/phel-pdo/issues/37
[#38]: https://github.com/phel-lang/phel-pdo/issues/38
[#39]: https://github.com/phel-lang/phel-pdo/issues/39
[#40]: https://github.com/phel-lang/phel-pdo/issues/40
[#41]: https://github.com/phel-lang/phel-pdo/issues/41
[#42]: https://github.com/phel-lang/phel-pdo/issues/42
[#43]: https://github.com/phel-lang/phel-pdo/issues/43
[#45]: https://github.com/phel-lang/phel-pdo/issues/45
[#46]: https://github.com/phel-lang/phel-pdo/issues/46
