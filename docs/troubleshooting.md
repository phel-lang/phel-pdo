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

If `require` itself fails, your `phel-lang` version may be too old. phel-pdo `>=0.1.0` needs phel-lang `^0.37`.

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
(pdo/fetch stmt) ; => {:id 1 :name "phel"}    ✓
(pdo/fetch stmt) ; => {"id" 1 "name" "phel"}  ✗ - not what you get
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

## Method I want isn't wrapped

Check the "Not implemented yet" block at the bottom of `src/pdo/statement.phel`. The escape hatch is always:

```clojure
(php/-> (conn :pdo)  (someMethod arg1 arg2))
(php/-> (stmt :stmt) (someMethod arg1 arg2))
```

…and a PR to wrap it properly is welcome - see [contributing](contributing.md#adding-a-wrapper).

## Tests pass locally but fail in CI

Most likely PHP version. CI pins `>=8.4`. Confirm with `php -v`. If you see deprecation warnings in `\PDO::__construct`, you're on an older PHP.
