# phel-pdo

PDO wrapper for [Phel](https://phel-lang.org). Pure Phel. Wraps `\PDO` and `\PDOStatement` so callers never touch `php/->`.

## Architecture

```
src/pdo.phel           public API (connection-side) + (load "pdo/statement") loader
src/pdo/statement.phel statement-side wrappers (in-ns phel.pdo)
tests/pdo_test.phel    deftest per behaviour; driver-parametric (PHEL_PDO_DSN), sqlite by default
bench/                 fetch_all.phel + insert_loop.phel, reproducible perf numbers
release.sh             release automation (CHANGELOG → tag → GitHub release)
phel-config.php        REQUIRED for consumers - phel finds a dependency's namespaces through it
```

Two structs, two files:

- `connection { :pdo owned state }` - opened by `pdo/connect`, threads through `exec`/`query`/`prepare`/`begin`/…
  `owned` distinguishes `connect` from `from-connection`; `state` is an atom holding the closed flag,
  the savepoint counter's peer, and the builders' statement cache.
- `statement  { :stmt bindings }` - returned by `prepare` / `query`, threads through `bind-value`/`execute`/`fetch`/…
  `bindings` is the `bind-column` → atom map read by `fetch-bound`.

**Both `defstruct` forms live in `src/pdo.phel`** - a `(load ...)`-ed file gets no PHP `namespace`
declaration, so a struct declared there lands in the global namespace (phel-lang#2834).

No PHP source. No PHPUnit. No rector / cs-fixer / phpstan.

## Testing

```bash
composer test     # vendor/bin/phel test
```

`.phel` edits auto-format via PostToolUse hook (`vendor/bin/phel format`).

## Adding a wrapper (see [/new-wrapper](skills/new-wrapper/SKILL.md))

1. Pick the file: connection-side → `src/pdo.phel`; statement-side → `src/pdo/statement.phel`.
2. Write `defn <return-tag> <kebab-name>` next to its peers. Mutator → return the struct; reader → return Phel data (route fetches through `row->map`).
3. Confirm it is not already wrapped - the PDO surface is complete, so new wrappers are additions rather than gap-filling.
4. Add a `deftest` in the matching section of `tests/pdo_test.phel`, driven through `*conn*` + `seed-t1` where possible.
5. Update the API table in `README.md` and `## [Unreleased]` in `CHANGELOG.md`.

## Git

- Conventional commits: `feat:`, `fix:`, `ref:`, `chore:`, `docs:`, `test:`, `ci:`. Never mention AI tooling.
- Branch prefixes: `feat/`, `fix/`, `ref/`, `docs/`.
- PRs: assign `@me`. Label one of `bug`, `enhancement`, `refactoring`, `documentation`, `pure testing`, `dependencies`. Use `Closes #N`.
- Release: `./release.sh <X.Y.Z>`.

## Style

- `defn-` for everything not in the public API. Public fns get a terse `:doc`.
- Pure functions only outside of the PDO call sites; no globals.
- kebab-case symbols. Threading (`->`, `->>`) and `case` for dispatch when it improves clarity.
