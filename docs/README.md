# phel-pdo docs

Developer docs for [phel-pdo](https://github.com/phel-lang/phel-pdo) — a thin, idiomatic PDO wrapper for [Phel](https://phel-lang.org).

New here? Read in order:

1. **[Getting started](getting-started.md)** — install, first query, run the test suite.
2. **[Architecture](architecture.md)** — how `connection` / `statement` are wrapped and why.
3. **[Recipes](recipes.md)** — transactions, prepared statements, bind types, phel-sql.
4. **[Troubleshooting](troubleshooting.md)** — common errors and fixes.
5. **[Contributing](contributing.md)** — local dev, adding wrappers, commits, PRs, releases.

The [top-level README](../README.md) keeps the quick start + API table. These docs are the deeper layer.

## At a glance

- **Single namespace** — everything is `phel.pdo` (`pdo/connect`, `pdo/fetch`, …).
- **Two structs** — `connection { :pdo }` and `statement { :stmt }` thread through `->`.
- **Phel-native data out** — fetches go through `row->map` so keys become keywords.
- **No PHP source** — pure Phel, no PHPUnit, no rector / cs-fixer / phpstan.
- **Errors are exceptions** — `ATTR_ERRMODE = ERRMODE_EXCEPTION` is set in `connect`.

## File map

```
src/pdo.phel              connection-side wrappers + (load "pdo/statement")
src/pdo/statement.phel    statement-side wrappers (in-ns phel.pdo)
tests/pdo_test.phel       deftest per behaviour; sqlite::memory: fixtures
release.sh                CHANGELOG → tag → GitHub release
docs/                     you are here
```
