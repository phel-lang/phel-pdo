# phel-pdo

PDO wrapper for [Phel](https://phel-lang.org). Pure Phel. Wraps `\PDO` and `\PDOStatement` so callers never touch `php/->`.

## Architecture

```
src/pdo.phel           public API (connection-side) + (load "pdo/statement") loader
src/pdo/statement.phel statement-side wrappers (in-ns phel.pdo)
tests/pdo_test.phel    deftest per behaviour; phel.test + sqlite::memory: fixtures
release.sh             release automation (CHANGELOG → tag → GitHub release)
phel-config.php        not used (≥ phel 0.37, library autoload via composer.json)
```

Two structs, two files:

- `connection { :pdo }` — opened by `pdo/connect`, threads through `exec`/`query`/`prepare`/`begin`/…
- `statement  { :stmt }` — returned by `prepare` / `query`, threads through `bind-value`/`execute`/`fetch`/…

No PHP source. No PHPUnit. No rector / cs-fixer / phpstan.

## Testing

```bash
composer test     # vendor/bin/phel test
```

`.phel` edits auto-format via PostToolUse hook (`vendor/bin/phel format`).

## Adding a wrapper (see [/new-wrapper](skills/new-wrapper/SKILL.md))

1. Pick the file: connection-side → `src/pdo.phel`; statement-side → `src/pdo/statement.phel`.
2. Write `defn <return-tag> <kebab-name>` next to its peers. Mutator → return the struct; reader → return Phel data (route fetches through `row->map`).
3. Drop the entry from the "Not implemented yet" block at the bottom of the file.
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
