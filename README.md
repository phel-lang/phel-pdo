# phel-pdo

PDO wrapper for [Phel](https://phel-lang.org). Talk to relational databases from Phel without dropping into PHP interop.

## Install

```bash
composer require phel-lang/phel-pdo
```

Requires PHP `>=8.4` and `phel-lang/phel-lang ^0.41`.

## Quick start

```clojure
(require phel.pdo)

(def conn (pdo/connect "sqlite::memory:"))
(pdo/exec conn "create table t1 (id integer primary key autoincrement, name varchar(10))")
(pdo/exec conn "insert into t1 (name) values ('phel'), ('php')")

;; Query with params - bound through a prepared statement, never interpolated
(-> (pdo/query conn "select * from t1 where id = ?" [1])
    (pdo/fetch))
;; => {:id 1, :name "phel"}

;; Named params work too
(-> (pdo/query conn "select * from t1 where id = :id" {:id 1})
    (pdo/fetch))
;; => {:id 1, :name "phel"}

;; Reuse a prepared statement across executions
(let [stmt (pdo/prepare conn "select * from t1 where id = :id")]
  (-> stmt (pdo/execute {:id 1}) (pdo/fetch)))
;; => {:id 1, :name "phel"}

;; Insert a row from a map
(pdo/insert conn :t1 {:name "lisp"})
;; => "3"   ; new last-insert-id (string, as PDO reports it)
```

`pdo/fetch` returns the row as a map keyed by column keyword, or `nil` when no rows remain.

## With phel-sql

[phel-sql](https://github.com/phel-lang/phel-sql) is an optional data-driven SQL DSL. It returns `[sql params]` you feed straight into `pdo/prepare` + `pdo/execute`:

```clojure
(let [[query params] (sql/format {:select [:id :name], :from [:users], :where [:= :id 1]})]
  (-> (pdo/prepare conn query)
      (pdo/execute params)
      (pdo/fetch)))
;; => {:id 1, :name "phel"}
```

## API

All functions live in the `phel.pdo` namespace.

### Connection

| Function | Signature | Description |
|---|---|---|
| `connect` | `(connect dsn & [username password options])` | Open a connection. Throws `PDOException` on failure. Sets `ERRMODE_EXCEPTION` by default. |
| `from-connection` | `(from-connection pdo & [options])` | Wrap an already-open `\PDO` (e.g. a framework/DBAL connection) as-is. `{:apply-defaults true}` sets `ERRMODE_EXCEPTION`. |
| `exec` | `(exec conn sql)` | Execute SQL, return number of affected rows. |
| `query` | `(query conn sql & [params options])` | Run SQL, binding `params` (map by name, vector positionally) through a prepared statement. Without params, uses `PDO::query`. `options` takes `{:fetch-mode …}`. |
| `prepare` | `(prepare conn sql & [options])` | Prepare a statement for later `execute`. |
| `select` | `(select conn sql & [params options])` | Run SQL and return every row. `options` takes `{:as :maps\|:rows}`, as `fetch-all`. |
| `select-one` | `(select-one conn sql & [params])` | First row as a map, or `nil`. |
| `select-value` | `(select-value conn sql & [params not-found])` | First column of the first row — `count(*)`, `max(id)`, an existence check. `not-found` (default `nil`) when there are no rows. |
| `insert` | `(insert conn table row)` | Insert a non-empty `row` map into `table` via a prepared statement and return the new `last-insert-id` (string). Identifiers must match `[A-Za-z_][A-Za-z0-9_]*`. |
| `update` | `(update conn table set-map where-map)` | `UPDATE` matched rows, return affected count. Both maps must be non-empty. |
| `delete` | `(delete conn table where-map)` | `DELETE` matched rows, return affected count. `where-map` must be non-empty. |
| `insert-many` | `(insert-many conn table rows)` | Insert a seq of same-keyed maps in one multi-`VALUES` statement, return affected count. |
| `quote` | `(quote conn string & [type])` | Quote a string for safe embedding in SQL. |
| `last-insert-id` | `(last-insert-id conn)` | ID of the last inserted row, as a string (as PDO reports it). |
| `begin` / `commit` / `rollback` | `(begin conn)` … | Transaction control. |
| `in-transaction` | `(in-transaction conn)` | `true` if a transaction is active. |
| `with-transaction` | `(with-transaction conn & body)` | Run `body` in a transaction: commit + return last value, or rollback + re-throw. When already in a transaction, `body` runs in a `SAVEPOINT` so a caught failure undoes only that block. |
| `with-savepoint` | `(with-savepoint conn f)` | Call `f` inside a `SAVEPOINT`: release + return its value, or roll back to it and re-throw. The primitive behind nested `with-transaction`. |
| `get-attribute` / `set-attribute` | `(get-attribute handle attr)` / `(set-attribute handle attr value)` | PDO attribute access; `handle` is a connection or a statement. |
| `get-available-drivers` | `(get-available-drivers)` | Vector of installed PDO drivers (static; no connection needed). |
| `error-code` | `(error-code handle)` | SQLSTATE string of the last operation; `handle` is a connection or a statement. |
| `error-info` | `(error-info handle)` | `[sqlstate driver-code driver-message]`; `handle` is a connection or a statement. |

### Statement

Returned by `pdo/query` and `pdo/prepare`.

| Function | Signature | Description |
|---|---|---|
| `execute` | `(execute stmt & [params])` | Run a prepared statement. A map binds by name, a vector positionally; each param's PDO type is inferred. Returns the statement so it threads through `->` / `let`. |
| `fetch` | `(fetch stmt)` | Next row as a map, or `nil` if exhausted. |
| `fetch-all` | `(fetch-all stmt & [options])` | Remaining rows. `{:as :maps}` (default) gives maps keyed by column keyword; `{:as :rows}` gives `{:cols […] :rows [[…]]}` — ~5x faster on large result sets. |
| `fetch-column` | `(fetch-column stmt & [column not-found])` | Single 0-indexed column from the next row, or `not-found` (default `nil`) once exhausted. A SQL `NULL` reads back as `nil`, so pass a distinct `not-found` to tell the two apart. |
| `fetch-object` | `(fetch-object stmt & [class-name ctor-args])` | Next row as an object (`stdClass` by default, or an instance of `class-name`), or `nil` if exhausted. |
| `statement-seq` | `(statement-seq stmt)` | Lazy seq of the remaining rows as maps, fetched one at a time. |
| `bind-value` | `(bind-value stmt column value & [type])` | Bind a value to a placeholder. `type` defaults to the type inferred from the value. Returns the statement. |
| `bind-param` | `(bind-param stmt column value & [type])` | Bind a parameter, applied at execution time. Same type inference as `bind-value`. Returns the statement. |
| `column-count` | `(column-count stmt)` | Number of columns in the result set. |
| `column-names` | `(column-names stmt)` | Result-set column names as a vector of keywords, in select order, or `nil` if the driver can't report them. |
| `row-count` | `(row-count stmt)` | Rows affected by the last DML. |
| `column-meta` | `(column-meta stmt column)` | Metadata map for a 0-indexed column, or `nil` if unavailable. |
| `close-cursor` | `(close-cursor stmt)` | Free the cursor so the statement can be re-executed. Returns the statement. |
| `set-fetch-mode` | `(set-fetch-mode stmt mode & args)` | Set the statement's default fetch mode (extra args match the mode). Returns the statement. |
| `next-rowset` | `(next-rowset stmt)` | Advance to the next rowset of a multi-rowset statement; `false` when none remain. |
| `debug-dump-params` | `(debug-dump-params stmt)` | Dump prepared statement info as a string. |

> [!NOTE]
> Unlike `PDOStatement::execute()` (returns `bool`), `pdo/execute` returns the statement itself so it composes with `->`.

## Development

```bash
composer install
vendor/bin/phel test
```

## Docs

Deeper docs live in [`docs/`](docs/README.md):

- [Getting started](docs/getting-started.md) - install, first query, run tests.
- [Architecture](docs/architecture.md) - `connection` / `statement` design and conventions.
- [Recipes](docs/recipes.md) - transactions, prepared statements, bind types, phel-sql.
- [Troubleshooting](docs/troubleshooting.md) - common errors and fixes.
- [Contributing](docs/contributing.md) - adding wrappers, commits, PRs, releases.
