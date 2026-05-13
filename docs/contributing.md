# Contributing

Thanks for picking up phel-pdo. This page is the contributor cheat sheet - for the *why* behind the design choices, see [architecture](architecture.md).

## Local setup

```bash
git clone https://github.com/phel-lang/phel-pdo.git
cd phel-pdo
composer install
composer test
```

Requires PHP `>=8.4`. The test suite uses `sqlite::memory:` - no external DB needed.

## Editing Phel

`.phel` files auto-format on save via the project's PostToolUse hook (`vendor/bin/phel format`). If you edit outside the agent, run it manually:

```bash
vendor/bin/phel format src tests
```

## Adding a wrapper

There's a step-by-step skill at `.claude/skills/new-wrapper/SKILL.md`. The short version:

1. **Pick the file.** Connection-side method → `src/pdo.phel`. Statement-side → `src/pdo/statement.phel`.
2. **Write the `defn` next to its peers.** Match the existing API conventions (see [architecture](architecture.md#conventions)):
   - First arg is the struct, then PDO args in PHP order, then `& [optional]`.
   - Optional args default inside the body via `(or x \PDO/DEFAULT)`.
   - Mutators return the wrapped struct; readers return Phel data via `row->map` or `php->phel`.
   - Public functions get a one-line `:doc`. Internal helpers use `defn-`.
3. **Drop the entry** from the "Not implemented yet" block at the bottom of the file.
4. **Add a `deftest`** in the matching section of `tests/pdo_test.phel`, driven through `*conn*` and `seed-t1` / `create-t1` / `insert-name` when possible. One behaviour per `deftest`; share setup via `testing` blocks.
5. **Update** the API table in `README.md` and the `## [Unreleased]` block in `CHANGELOG.md`.

## Testing

Single test file: `tests/pdo_test.phel`. Run everything:

```bash
composer test
# or
vendor/bin/phel test tests/pdo_test.phel
```

> [!NOTE]
> The Phel test runner has no `--filter`. To narrow execution, edit the file or copy the test you care about into a scratch file.

Conventions:

- `(use-fixtures :each db-fixture)` binds `*conn*` to a fresh `sqlite::memory:` per `deftest`.
- One `deftest` per behaviour. Test names describe behaviour (`commit-persists-changes`, `fetch-returns-nil-when-no-rows`).
- Reuse `create-t1` / `insert-name` / `seed-t1`. Add a new helper only if you need a new schema.
- Group related tests with `;; ----` section comments.
- For PDO errors: wrap the failing call in `(try ... (catch \PDOException _e nil))`, then assert via `pdo/error-code` / `pdo/error-info`.

## Git workflow

- **Conventional commits**: `feat:`, `fix:`, `ref:`, `chore:`, `docs:`, `test:`, `ci:`. Never mention AI tooling. Use `ref:` (not `refactor:`).
- **Branch prefixes**: `feat/`, `fix/`, `ref/`, `docs/`.
- **PRs**: assign yourself. Label one of `bug`, `enhancement`, `refactoring`, `documentation`, `pure testing`, `dependencies`. Use `Closes #N` in the body to auto-close issues.

Example commit:

```
feat: wrap PDOStatement::closeCursor

Adds `pdo/close-cursor` so callers can re-execute a prepared statement
without dropping into `php/->`. Returns the statement for threading.
```

## Releasing

Maintainers only:

```bash
./release.sh 0.2.0
```

`release.sh` rolls the `## [Unreleased]` block into a new version section in `CHANGELOG.md`, tags `v0.2.0`, and creates a GitHub release. Review the diff before pushing.

## Not goals

Please don't open PRs for any of these - they were explicitly removed or never added:

- PHPUnit, rector, cs-fixer, phpstan. This project is Phel-only by design.
- A `phel-config.php` (not needed since Phel 0.37; library autoload is via `composer.json`).
- A `Dockerfile` / `compose.yaml`. Library installs via composer; dev needs no Docker.
- A query builder. Use [phel-sql](https://github.com/phel-lang/phel-sql).

## Project rules

The `.claude/rules/` directory has the canonical, agent-readable versions of these conventions:

- `.claude/rules/api-design.md` - public surface rules.
- `.claude/rules/testing.md` - fixture and test conventions.
- `.claude/rules/phel.md` - Phel idioms and naming.

If you change a convention here, update the matching rules file too.
