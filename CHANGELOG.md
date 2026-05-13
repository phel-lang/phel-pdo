# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/phel-lang/phel-pdo/compare/v0.0.8...HEAD
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
[#2]: https://github.com/phel-lang/phel-pdo/pull/2
[#3]: https://github.com/phel-lang/phel-pdo/issues/3
