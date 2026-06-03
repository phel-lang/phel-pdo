# Recipes

Common patterns. Every snippet assumes:

```clojure
(require phel.pdo)
(def conn (pdo/connect "sqlite::memory:"))
```

## Reuse an existing (framework) connection

Inside a PHP host (Symfony, Laravel) the app already has a configured, pooled
connection. Hand its native `\PDO` to `from-connection` instead of opening a
second one - Doctrine DBAL exposes it via `getNativeConnection()`:

```clojure
;; php-pdo is a \PDO passed in from the host framework
(def conn (pdo/from-connection php-pdo))

(-> (pdo/query conn "select * from products where id = 1")
    (pdo/fetch))
```

`from-connection` reuses the handle as-is and leaves its attributes untouched -
the host owns the connection's configuration, and phel-pdo never closes a
connection it did not open. Pass `{:apply-defaults true}` to opt into
phel-pdo's `ERRMODE_EXCEPTION`:

```clojure
(def conn (pdo/from-connection php-pdo {:apply-defaults true}))
```

## Prepared statements

Reuse a statement across many parameter sets:

```clojure
(let [stmt (pdo/prepare conn "insert into t1 (name) values (:name)")]
  (pdo/execute stmt {:name "phel"})
  (pdo/execute stmt {:name "php"})
  (pdo/execute stmt {:name "clojure"}))
```

`execute` returns the statement, so it threads:

```clojure
(-> (pdo/prepare conn "select * from t1 where id = :id")
    (pdo/execute {:id 1})
    (pdo/fetch))
;; => {:id 1 :name "phel"}
```

> [!NOTE]
> `pdo/execute` returns the statement (not `bool` like raw `PDOStatement::execute()`) so it composes with `->`.

## Fetching

| You want | Use |
|---|---|
| One row, then `nil` | `pdo/fetch` |
| All rows as a vector of maps | `pdo/fetch-all` |
| Just one column from the next row | `pdo/fetch-column` |
| Number of rows affected by last DML | `pdo/row-count` |
| Number of columns in the result set | `pdo/column-count` |

```clojure
(-> (pdo/query conn "select count(*) from t1")
    (pdo/fetch-column))
;; => 3
```

## Binding values explicitly

`bind-value` is for when you want to control the PDO param type (e.g. `PARAM_INT` vs the default `PARAM_STR`):

```clojure
(-> (pdo/prepare conn "select * from t1 where id = :id")
    (pdo/bind-value :id 1 \PDO/PARAM_INT)
    (pdo/execute)
    (pdo/fetch))
```

Available types: `\PDO/PARAM_STR` (default), `\PDO/PARAM_INT`, `\PDO/PARAM_BOOL`, `\PDO/PARAM_NULL`, `\PDO/PARAM_LOB`.

## Transactions

Use `with-transaction` to bracket a body: it commits on success (returning the
last body value) and rolls back + re-throws on any exception.

```clojure
(pdo/with-transaction conn
  (pdo/insert conn :accounts {:name "a" :balance 100})
  (pdo/insert conn :accounts {:name "b" :balance 0}))
```

If `conn` is already in a transaction, the body runs inline - no nested
`begin`/`commit` (v1 uses no savepoints).

The manual primitives remain available when you need finer control:

```clojure
(pdo/begin conn)
(try
  (pdo/exec conn "insert into t1 (name) values ('phel')")
  (pdo/exec conn "insert into t1 (name) values ('php')")
  (pdo/commit conn)
  (catch \PDOException _e
    (pdo/rollback conn)))
```

Check state with `(pdo/in-transaction conn)`.

## Last insert ID

```clojure
(pdo/exec conn "insert into t1 (name) values ('phel')")
(pdo/last-insert-id conn)
;; => "1"
```

Returns a `string` (as PDO reports it) - lossless for big integers and named
sequences; coerce with `php/intval` when you need a number. On PostgreSQL pass the
sequence name to raw PDO (not yet wrapped - drop into `(php/-> (conn :pdo) (lastInsertId "seq"))` for now).

## Quoting

Prefer prepared statements. For the rare case where you need to inline a value (e.g., dynamic identifiers that PDO won't bind):

```clojure
(pdo/quote conn "I'm fine.")
;; => "'I''m fine.'"
```

Pass a type as the third arg if you need something other than `PARAM_STR`.

## Errors

`connect` sets `ERRMODE_EXCEPTION`, so failures throw `\PDOException`. Catch and inspect via `error-code` / `error-info`:

```clojure
(try
  (pdo/exec conn "insert into t1 (id, name) values (1, 'dup')")
  (catch \PDOException _e nil))

(pdo/error-code conn)   ; => "23000"
(pdo/error-info conn)   ; => ["23000" 19 "UNIQUE constraint failed: t1.id"]
```

`error-code` returns the SQLSTATE string. `error-info` returns `[sqlstate driver-code driver-message]` - `sqlstate` is the SQLSTATE string, `driver-code` the driver-specific integer.

## Attributes

Read or change PDO attributes per connection:

```clojure
(pdo/get-attribute conn \PDO/ATTR_ERRMODE)
;; => \PDO/ERRMODE_EXCEPTION

(pdo/set-attribute conn \PDO/ATTR_DEFAULT_FETCH_MODE \PDO/FETCH_ASSOC)
```

## Available drivers

```clojure
(pdo/get-available-drivers)
;; => ["mysql" "sqlite" ...]
```

Returns a Phel vector - `contains-value?` works directly.

## Using phel-sql

[phel-sql](https://github.com/phel-lang/phel-sql) is a data-driven SQL DSL. It returns `[sql params]` from plain data - feed that straight in:

```clojure
(require phel.pdo)
(require phel.sql :as sql)

(let [[query params] (sql/format {:select [:id :name]
                                  :from   [:users]
                                  :where  [:= :id 1]})]
  (-> (pdo/prepare conn query)
      (pdo/execute params)
      (pdo/fetch)))
;; => {:id 1 :name "phel"}
```

phel-pdo + phel-sql is the recommended combo when you'd otherwise build SQL strings by hand.

## Debugging a prepared statement

```clojure
(-> (pdo/prepare conn "select * from t1 where name = :name")
    (pdo/bind-value :name "phel")
    (pdo/debug-dump-params))
;; => "SQL: [35] select * from t1 where name = :name ..."
```

`debug-dump-params` captures `PDOStatement::debugDumpParams()` into a string - handy in REPL sessions.
