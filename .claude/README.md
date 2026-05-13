# Claude Code project config

Repo-maintenance config for phel-pdo. Inspired by `.claude/` in [phel-lang/phel-lang](https://github.com/phel-lang/phel-lang/tree/main/.claude) and [phel-lang/phel-sql](https://github.com/phel-lang/phel-sql/tree/main/.claude), trimmed for a thin wrapper library.

| Path | Purpose |
|------|---------|
| `CLAUDE.md` | Project entrypoint loaded into context. |
| `settings.json` | Permissions, hooks, status line. |
| `statusline.sh` | Branch / model / cost / tokens / context %. |
| `hooks/` | `format-phel.sh` (PostToolUse), `protect-files.sh` (PreToolUse), `compact-context.sh` (SessionStart). |
| `agents/` | `clean-code-reviewer`, `debugger`, `tdd-coach`, `explorer`, `changelog-keeper`. |
| `rules/` | `phel.md`, `testing.md`, `api-design.md`. |
| `skills/` | `commit`, `pr`, `gh-issue`, `release`, `changelog`, `test`, `phel-repl`, `new-wrapper`. |

No PHP source, no PHPUnit, no static analysis pipeline. Single test command (`composer test`), single formatter (`vendor/bin/phel format`).
