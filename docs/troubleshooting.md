# Troubleshooting

## `could not find driver`

```
PDOException: could not find driver
```

The PDO driver for your DSN isn't installed. Check what PHP actually has:

```bash
php -r 'print_r(PDO::getAvailableDrivers());'
```

Then install the matching extension (e.g. `pdo_mysql`, `pdo_pgsql`, `pdo_sqlite`) for your PHP build.

## `Cannot resolve symbol 'pdo/...'`

You forgot to `(require phel.pdo)`. Everything - connection-side and statement-side - lives under that single namespace.

If `require` itself fails, your `phel-lang` version may be too old. phel-pdo needs phel-lang `^0.41`.

## Bound integer matches as a string

```clojure
;; works but binds as string
(pdo/bind-value stmt :id 1)

;; binds as int - use this when the driver is type-sensitive
(pdo/bind-value stmt :id 1 \PDO/PARAM_INT)
```

`bind-value` defaults to `\PDO/PARAM_STR`. Drivers like PostgreSQL care; MySQL and SQLite often coerce silently.

## `fetch` returned `nil`, I expected `{}`

That's intentional. `pdo/fetch` returns `nil` when the cursor is exhausted (since 0.1.0). Use `when-let` or `if-let`:

```clojure
(when-let [row (pdo/fetch stmt)]
  (do-thing row))
```

If you want all rows up front, `pdo/fetch-all` returns a vector (empty when no rows).

## Keyword keys vs string keys

Rows go through `row->map`, so keys are keywords:

```clojure
(pdo/fetch stmt) ; => {:id 1, :name "phel"}    ✓
(pdo/fetch stmt) ; => {"id" 1, "name" "phel"}  ✗ - not what you get
```

For `execute` params, keyword keys are fine - `phel->php` converts them to string keys for PDO:

```clojure
(pdo/execute stmt {:id 1})   ; works
(pdo/execute stmt {"id" 1})  ; also works
```

## `SQLSTATE[HY000]: General error: 2014 Cannot execute queries while other unbuffered queries are active`

MySQL-specific. You opened a second query before draining the first. Either:

- Call `pdo/fetch-all` on the first statement, or
- Set `\PDO/MYSQL_ATTR_USE_BUFFERED_QUERY` to `true` via the options arg to `pdo/connect`.

## Transactions don't roll back

Two usual causes:

1. **DDL auto-commits.** MySQL commits implicitly on `CREATE TABLE`, `ALTER TABLE`, etc. Nothing to roll back. SQLite and PostgreSQL are fine.
2. **No transaction was active.** Check `(pdo/in-transaction conn)` before `rollback`.

## `\PDOException` not raised on bad SQL

phel-pdo sets `ERRMODE_EXCEPTION` in `connect`. If you've overridden it:

```clojure
(pdo/set-attribute conn \PDO/ATTR_ERRMODE \PDO/ERRMODE_SILENT)
```

…then errors go silent. Either revert it (`\PDO/ERRMODE_EXCEPTION`) or read `pdo/error-code` / `pdo/error-info` after every call. The default is the saner mode for almost every app.

## `last-insert-id` is wrong on PostgreSQL

PostgreSQL needs the sequence name. The wrapped `pdo/last-insert-id` calls `lastInsertId()` with no args. Until a sequence-aware wrapper lands, drop down to raw PDO:

```clojure
(php/-> (conn :pdo) (lastInsertId "t1_id_seq"))   ; => "42" (string)
```

`pdo/last-insert-id` returns the value as a string (as PDO does); coerce with `php/intval` only when you actually need a number.

## `error-code` on a connection returns "00000" after a failed statement

`pdo/error-code` and `pdo/error-info` forward PDO's own error state, and PDO only
records a failed `exec()` against the **connection** on SQLite. `pdo_mysql` and
`pdo_pgsql` attach it to the result and leave the connection reporting `"00000"`.

Two things work everywhere:

```clojure
;; the statement handle
(let [stmt (pdo/prepare conn sql)]
  (try (pdo/execute stmt) (catch \PDOException _e nil))
  (pdo/error-code stmt))

;; or the exception, which always carries it
(try
  (pdo/exec conn sql)
  (catch \PDOException e (php/-> e (getCode))))
```

Note also that **any** successful PDO call clears the error state - including
`pdo/get-attribute`. Read the error before you do anything else with the handle.

## `Class "phel\pdo\statement" not found`

```
Class "phel\pdo\statement" not found
  at .phel/cache/compiled/phel.pdo__c344736d.php:45
```

Clear the cache and it goes away:

```bash
rm -rf .phel/cache
```

**What causes it.** A file pulled in with `(load ...)` compiles to its own cache
entry, and that entry carries no PHP `namespace` declaration. Any `defstruct` in
such a file therefore declares its class in the *global* namespace, while call
sites reference the qualified name. The first run compiles in-process and works;
the second reads the cache and fails.

It is a phel-lang compiler issue rather than a phel-pdo one - reproducible in
twenty lines with no PDO involved, by running any project with a `(load ...)`-ed
`defstruct` twice.

phel-pdo avoids it by declaring **both** structs in `src/pdo.phel`, the file that
does carry the namespace. If you are hitting this in your own project, move your
`defstruct` forms into the file with the `(ns ...)` form.

## Method I want isn't wrapped

Check `README.md`'s API tables first - the PDO surface is fully wrapped, so the
method probably exists under a kebab-case name (`lastInsertId` → `last-insert-id`).

One method has no direct equivalent: `PDOStatement::bindColumn` binds a PHP
variable by reference, and Phel has no by-reference locals to offer it. Use
`pdo/bind-column` + `pdo/fetch-bound`, which do the same job with atoms.

For anything genuinely unwrapped, the escape hatch is always:

```clojure
(php/-> (conn :pdo)  (someMethod arg1 arg2))
(php/-> (stmt :stmt) (someMethod arg1 arg2))
```

…and a PR to wrap it properly is welcome - see [contributing](contributing.md#adding-a-wrapper).

## Tests pass locally but fail in CI

Most likely PHP version. CI pins `>=8.4`. Confirm with `php -v`. If you see deprecation warnings in `\PDO::__construct`, you're on an older PHP.
