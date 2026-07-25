# Architecture

phel-pdo is a single-namespace, two-struct wrapper around `\PDO` and `\PDOStatement`. The goal: callers never write `php/->` themselves.

## Layout

```
src/pdo.phel              (ns phel.pdo)        connection-side wrappers + both defstructs
src/pdo/statement.phel    (in-ns phel.pdo)     statement-side wrappers
tests/pdo_test.phel                            one suite, three drivers
bench/                                         reproducible performance numbers
```

`src/pdo.phel` ends with `(load "pdo/statement")` so both files share one namespace. Anything in `statement.phel` that `pdo.phel` references is forward-declared with `declare` before the `load` - see the `fetch` / `fetch-all` / `close-cursor` declarations that the connection-side readers depend on.

> [!NOTE]
> One namespace, two files. Public API is `phel.pdo/*` regardless of which file a function lives in.

## The two structs

```clojure
(defstruct connection [pdo owned state])   ; wraps \PDO
(defstruct statement  [stmt bindings])     ; wraps \PDOStatement
```

> [!IMPORTANT]
> **Both** structs are declared in `src/pdo.phel`, even though `statement`'s
> functions live in `src/pdo/statement.phel`. A file pulled in with `(load ...)`
> compiles to its own cache entry that carries no PHP `namespace` declaration, so
> a `defstruct` there lands in the global namespace while every call site
> references the qualified name - `Class "phel\pdo\statement" not found` on the
> second run. Keep new `defstruct` forms in `src/pdo.phel`.

- `owned` - `true` for a connection `connect` opened, `false` for one
  `from-connection` borrowed. `close` never disturbs a borrowed handle.
- `state` - an atom holding `{:closed bool}`. It has to be an atom rather than a
  plain field: `close` must invalidate *every* reference to the connection, and a
  new struct returned from `close` would leave the caller's binding pointing at
  the old one.
- `bindings` - column → atom, populated by `bind-column`. The struct itself stays
  immutable; `bind-column` returns a new statement, and the caller's atoms are the
  only mutable cells.

### What `close` can and cannot promise

PDO has no `close()`. The connection is released when the last reference to the
`\PDO` object goes out of scope. So `close` drops phel-pdo's *use* of it
immediately and deterministically - further calls raise - while the socket itself
goes when the struct does. `with-connection` scopes the struct so that happens
promptly. The docstring says exactly this; a `close` that quietly promises more
would be worse than none.

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

### The one piece of module state

Everything outside the PDO call sites is a pure function, with a single
deliberate exception: `savepoint-counter`, a private atom in `src/pdo.phel`.

Nested `with-transaction` brackets its body with a `SAVEPOINT`, and each nesting
level needs a distinct name or `ROLLBACK TO` unwinds to the wrong one. Savepoint
names are SQL identifiers, so they cannot be bound as parameters - they have to
be generated. A monotonic counter is the smallest thing that guarantees
uniqueness across sibling blocks in a loop, which `php/uniqid` would not.

The counter is private, is never read by callers, and never takes caller input.

The connection's `state` atom also holds a small bounded cache of prepared
statements, used **only** by `insert` / `update` / `delete` / `insert-many`. Those
own their statement for the whole of its life - prepared, executed, read,
discarded - so reuse is safe. `prepare` is not cached: it hands the statement to
the caller, and two live users of one statement would silently share a cursor.
No opt-in flag can prevent that, so the general cache is not offered.

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
- Mirroring PDO exactly. The surface is fully wrapped, but where PDO's mechanism does not fit Phel the wrapper takes the Phel-native route instead - see `bind-column`, which uses atoms because Phel has no by-reference locals for `PDOStatement::bindColumn`.
