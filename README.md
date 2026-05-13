# phel-pdo

PDO wrapper for [Phel](https://phel-lang.org). Talk to relational databases from Phel without dropping into PHP interop.

## Install

```bash
composer require phel-lang/phel-pdo
```

Requires PHP `>=8.4` and `phel-lang/phel-lang ^0.37`.

## Quick start

```clojure
(require phel.pdo)

(def conn (pdo/connect "sqlite::memory:"))
(pdo/exec conn "create table t1 (id integer primary key autoincrement, name varchar(10))")
(pdo/exec conn "insert into t1 (name) values ('phel'), ('php')")

;; Raw query
(-> (pdo/query conn "select * from t1 where id = 1")
    (pdo/fetch))
;; => {:id 1 :name "phel"}

;; Prepared statement
(-> (pdo/prepare conn "select * from t1 where id = :id")
    (pdo/execute {:id 1})
    (pdo/fetch))
;; => {:id 1 :name "phel"}
```

`pdo/fetch` returns the row as a map keyed by column keyword, or `nil` when no rows remain.

## With phel-sql

[phel-sql](https://github.com/phel-lang/phel-sql) is a data-driven SQL DSL (HoneySQL-style). It returns `[sql params]` from plain data — feed that straight into `pdo/prepare` + `pdo/execute`:

```bash
composer require phel-lang/phel-sql
```

```clojure
(require phel.pdo)
(require phel.sql :as sql)

(let [[query params] (sql/format {:select [:id :name]
                                  :from   [:users]
                                  :where  [:= :id 1]})
      conn           (pdo/connect "sqlite:database.db")]
  (-> (pdo/prepare conn query)
      (pdo/execute params)
      (pdo/fetch)))
;; => {:id 1 :name "phel"}
```

phel-sql is optional — phel-pdo works with raw SQL strings on its own.

## API

All functions live in the `phel.pdo` namespace.

### Connection

| Function | Signature | Description |
|---|---|---|
| `connect` | `(connect dsn & [username password options])` | Open a connection. Throws `PDOException` on failure. Sets `ERRMODE_EXCEPTION` by default. |
| `exec` | `(exec conn sql)` | Execute SQL, return number of affected rows. |
| `query` | `(query conn sql & [fetch-mode])` | Run SQL without placeholders, return a statement. |
| `prepare` | `(prepare conn sql & [options])` | Prepare a statement for later `execute`. |
| `quote` | `(quote conn string & [type])` | Quote a string for safe embedding in SQL. |
| `last-insert-id` | `(last-insert-id conn)` | ID of the last inserted row. |
| `begin` / `commit` / `rollback` | `(begin conn)` … | Transaction control. |
| `in-transaction` | `(in-transaction conn)` | `true` if a transaction is active. |
| `get-attribute` / `set-attribute` | `(get-attribute conn attr)` / `(set-attribute conn attr value)` | PDO attribute access. |
| `get-available-drivers` | `(get-available-drivers conn)` | Vector of installed PDO drivers. |
| `error-code` | `(error-code conn)` | SQLSTATE of the last operation. |
| `error-info` | `(error-info conn)` | `[sqlstate driver-code driver-message]`. |

### Statement

Returned by `pdo/query` and `pdo/prepare`.

| Function | Signature | Description |
|---|---|---|
| `execute` | `(execute stmt & [params])` | Run a prepared statement. Returns the statement so it threads through `->` / `let`. |
| `fetch` | `(fetch stmt)` | Next row as a map, or `nil` if exhausted. |
| `fetch-all` | `(fetch-all stmt)` | Remaining rows as a vector of maps. |
| `fetch-column` | `(fetch-column stmt & [column])` | Single column from the next row. |
| `bind-value` | `(bind-value stmt column value & [type])` | Bind a value to a placeholder. Returns the statement. |
| `column-count` | `(column-count stmt)` | Number of columns in the result set. |
| `row-count` | `(row-count stmt)` | Rows affected by the last DML. |
| `debug-dump-params` | `(debug-dump-params stmt)` | Dump prepared statement info as a string. |

> [!NOTE]
> Unlike `PDOStatement::execute()` (returns `bool`), `pdo/execute` returns the statement itself so it composes with `->`.

## Development

```bash
composer install
vendor/bin/phel test
```
