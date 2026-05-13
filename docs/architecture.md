# Architecture

phel-pdo is a single-namespace, two-struct wrapper around `\PDO` and `\PDOStatement`. The goal: callers never write `php/->` themselves.

## Layout

```
src/pdo.phel              (ns phel.pdo)        connection-side wrappers
src/pdo/statement.phel    (in-ns phel.pdo)     statement-side wrappers
```

`src/pdo.phel` ends with `(load "pdo/statement")` so both files share one namespace. Anything in `statement.phel` that `pdo.phel` references is forward-declared via `(declare statement)`.

> [!NOTE]
> One namespace, two files. Public API is `phel.pdo/*` regardless of which file a function lives in.

## The two structs

```clojure
(defstruct connection [pdo])    ; wraps \PDO
(defstruct statement  [stmt])   ; wraps \PDOStatement
```

Field access is plain keyword lookup (`(conn :pdo)`, `(stmt :stmt)`). The PHP boundary is always crossed inside the wrapper:

```clojure
(php/-> (conn :pdo)  (exec sql))
(php/-> (stmt :stmt) (fetch \PDO/FETCH_ASSOC))
```

## Conventions

The wrapper follows a few rules so the public surface stays predictable:

| Rule | Why |
|---|---|
| One Phel function per PDO method, kebab-case (`lastInsertId` → `last-insert-id`). | One-to-one map; no surprises. |
| First arg is the struct (`conn` / `stmt`), then PDO args in PHP order, then `& [optional]`. | Threads cleanly with `->`. |
| Optional args default in the body via `(or x \PDO/DEFAULT)`, not via overloads. | No arity explosion. |
| Mutators return the wrapped struct. | `(-> stmt (bind-value …) (execute) (fetch))` reads top to bottom. |
| Reads return Phel-native data. | Maps with keyword keys, vectors of maps, ints, strings. |
| Rows go through `row->map`. | Keys become keywords automatically. |
| Param maps go through `phel->php`. | Keyword keys → string keys for PDO. |
| `ERRMODE_EXCEPTION` is set in `connect`. | Errors surface as `\PDOException` - don't re-wrap. |
| Public functions never expose raw `\PDO` / `\PDOStatement`. | Wrapper stays the only seam. |

## Boundary crossings

The only places PHP data and Phel data meet:

| Direction | Helper | Where it's used |
|---|---|---|
| Phel → PHP | `phel->php` | `prepare` options, `execute` params. |
| PHP → Phel | `php->phel` | `error-info`, `get-available-drivers`. |
| PHP row → Phel map | `row->map` (private) | `fetch`, `fetch-all`. |

```clojure
(defn- row->map [row]
  (into {} (for [[k v] :pairs (php->phel row)] [(keyword k) v])))
```

Every fetch routes through it, so result-set keys are always keywords.

## Why these choices

- **Single namespace** - keeps the import story to one line: `(require phel.pdo)`.
- **Structs, not opaque handles** - `(conn :pdo)` is escape-valve interop for the 1% case the wrapper doesn't cover.
- **Thread-friendly returns** - `execute` returns `stmt` (not `bool` like raw PDO) on purpose: pipelines compose.
- **Exception mode by default** - silent-error mode in raw PDO has bitten enough Phel callers that we just turn it on.

## Not goals

- A query builder. Use [phel-sql](https://github.com/phel-lang/phel-sql) for that - it returns `[sql params]` you feed straight into `prepare` + `execute`. See [recipes](recipes.md#using-phel-sql).
- A connection pool / ORM / migration tool.
- Wrapping every last PDO method. See the "Not implemented yet" block at the bottom of `src/pdo/statement.phel`; PRs welcome.
