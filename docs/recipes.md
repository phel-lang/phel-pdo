# Recipes

Common patterns. Every snippet assumes:

```clojure
(require phel.pdo)
(def conn (pdo/connect "sqlite::memory:"))
```

## Reuse an existing (framework) connection

Inside a PHP host (Symfony, Laravel) hand the app's native `\PDO` to
`from-connection` instead of opening a second one (Doctrine DBAL exposes it via
`getNativeConnection()`). The handle is reused as-is, attributes untouched, and
phel-pdo never closes a connection it did not open:

```clojure
;; php-pdo is a \PDO passed in from the host framework
(def conn (pdo/from-connection php-pdo))

;; pass {:apply-defaults true} to opt into phel-pdo's ERRMODE_EXCEPTION
(def conn (pdo/from-connection php-pdo {:apply-defaults true}))
```

## Bound columns

PDO's `FETCH_BOUND` writes each fetched column straight into a variable. Phel has
no by-reference locals to hand `PDOStatement::bindColumn`, so `pdo/bind-column`
binds an **atom** instead:

```clojure
(let [id   (atom nil)
      name (atom nil)
      stmt (-> (pdo/prepare conn "select id, name from t1 order by id")
               (pdo/execute)
               (pdo/bind-column 1 id)
               (pdo/bind-column :name name))]
  (while (pdo/fetch-bound stmt)
    (println (deref id) (deref name))))
```

`column` is a 1-based position (as PDO numbers them) or a column name.
`bind-column` returns a *new* statement carrying the binding, so it threads -
the statement struct stays immutable and the atoms are the only mutable cells.

`fetch-bound` returns `false` once the cursor is exhausted, leaving the atoms at
their last values, which is what PDO does with its bound variables.

For most work `pdo/fetch` or `pdo/statement-seq` is simpler - reach for bound
columns when you are porting PHP that already uses `FETCH_BOUND`.

## Matching a list with `IN`

One placeholder binds one scalar, so `where id in (?)` with `[1 2 3]` matches
nothing rather than erroring. This is the one thing PDO genuinely cannot do, and
the usual workaround - generating N placeholders by string concatenation - is
exactly what this library exists to keep you away from.

`pdo/expand-in` returns `[sql params]`, the same shape
[phel-sql](https://github.com/phel-lang/phel-sql) produces:

```clojure
(let [[sql params] (pdo/expand-in "select * from t1 where id in (?) and status = ?"
                                  [[1 2 3] "active"])]
  (pdo/select conn sql params))

;; sql    => "select * from t1 where id in (?, ?, ?) and status = ?"
;; params => [1 2 3 "active"]
```

Named params work the same way, expanding to `:ids_0`, `:ids_1`, …:

```clojure
(let [[sql params] (pdo/expand-in "select * from t1 where id in (:ids)" {:ids [1 2 3]})]
  (pdo/select conn sql params))
```

Scalars pass through untouched, and several lists in one statement each expand
independently.

### What it will not touch

A `?` or `:name` is only a placeholder when it is really one. Inside a string
literal, a quoted identifier (`"..."` or `` `...` ``), or a comment, it is data:

```clojure
(pdo/expand-in "select * from t1 where note = 'why?' and id in (?)" [[1 2]])
;; => ["select * from t1 where note = 'why?' and id in (?, ?)" [1 2]]
```

Postgres' `::` cast is not read as a named placeholder either. Getting any of
this wrong would silently shift every later binding by one, which is why it is
handled by a scanner rather than a regex.

### Errors

An empty list raises rather than emitting `IN (NULL)`. `IN ()` is invalid SQL
everywhere, and a silently never-matching predicate looks like data instead of a
bug. A params/placeholder count mismatch raises too, rather than reaching PDO.

## CRUD from maps

`insert` / `update` / `delete` / `insert-many` build the statement from maps.
Identifiers are validated against `[A-Za-z_][A-Za-z0-9_]*`; every value is bound.

```clojure
(pdo/insert conn :users {:name "phel"})                    ; => "1"  (last-insert-id)
(pdo/update conn :users {:name "lisp"} {:id 1})            ; => 1    (affected rows)
(pdo/delete conn :users {:id 1})                           ; => 1    (affected rows)
(pdo/insert-many conn :users [{:name "a"} {:name "b"}])    ; => 2    (affected rows)
```

`update` prefixes its placeholders by clause, so the same column on both sides
binds two different values:

```clojure
(pdo/update conn :users {:id 99} {:id 1})
;; UPDATE users SET id = :set_id WHERE id = :where_id
```

### Guard rails

An empty `where` map **raises** rather than generating an unqualified statement:

```clojure
(pdo/update conn :users {:name "x"} {})   ; InvalidArgumentException
(pdo/delete conn :users {})               ; InvalidArgumentException
```

A missing where clause never means "every row" - silently rewriting or emptying
a table is not a reasonable default. Write the raw SQL if that is genuinely what
you want.

`insert-many` requires every row to have the same keys, since a single `INSERT`
has one column list. It returns an affected row count rather than an id: for a
multi-row insert the id is driver-specific (MySQL reports the first, SQLite the
last). Its statement carries `rows × columns` placeholders, which drivers cap -
chunk very large batches yourself.

For anything past this - joins, `or`, ranges, ordering - reach for
[phel-sql](https://github.com/phel-lang/phel-sql). These four cover the flat-map
cases and stop there deliberately.

## One-shot reads

Most reads want rows, not a statement. Three helpers go straight there:

```clojure
(pdo/select conn "select * from users where age > ?" [18])
;; => [{:id 1, :name "phel"} {:id 2, :name "php"}]     ; [] when no rows

(pdo/select-one conn "select * from users where id = ?" [1])
;; => {:id 1, :name "phel"}                            ; nil when no rows

(pdo/select-value conn "select count(*) from users")
;; => 42                                               ; nil when no rows
```

`select-value` is the one you reach for most: scalar reads - `count(*)`,
`max(id)`, an existence check - otherwise cost four calls and a keyword lookup.

Both `select-one` and `select-value` return `nil` for "no rows", which is also
what a SQL `NULL` column gives. When you need to tell them apart, `select-value`
takes a sentinel:

```clojure
(pdo/select-value conn "select nickname from users where id = ?" [1] :missing)
;; => :missing   ; no such user
;; => nil        ; user exists, nickname is NULL
```

`select` forwards its options to `pdo/fetch-all`, so the column-oriented shape is
available here too:

```clojure
(pdo/select conn "select id, name from big" nil {:as :rows})
;; => {:cols [:id :name] :rows [[1 "phel"] ...]}
```

All three release the cursor before returning, and none of them rewrites your
SQL - `select-one` fetches one row rather than appending a `LIMIT`.

## One-off queries with params

When you want the statement itself - to bind more, to stream, to check
`row-count` - `pdo/query` binds params and hands it back:

```clojure
(-> (pdo/query conn "select * from t1 where id = ?" [1])
    (pdo/fetch))
;; => {:id 1, :name "phel"}

(-> (pdo/query conn "select * from t1 where name = :name" {:name "phel"})
    (pdo/fetch-all))
```

A vector binds positionally (1-based), a map binds by name. Either way the
values go through a prepared statement - they are never spliced into the SQL
string, so `"'; drop table t1; --"` is just an unusual name.

Without params, `pdo/query` uses `PDO::query` directly and skips the prepare.

To set the statement's native fetch mode, pass it in the options map:

```clojure
(pdo/query conn "select name from t1" nil {:fetch-mode \PDO/FETCH_NUM})
```

## Prepared statements

Reach for `pdo/prepare` when you want to reuse one statement across many
parameter sets:

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
;; => {:id 1, :name "phel"}
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

`pdo/fetch-column` returns `nil` once the cursor is exhausted, the same as
`pdo/fetch`. A SQL `NULL` column also reads back as `nil` - when you need to tell
"no more rows" from "the column was NULL", pass a sentinel:

```clojure
(-> (pdo/query conn "select name from t1 where id = 999")
    (pdo/fetch-column 0 :eof))
;; => :eof     ; no row at all

(-> (pdo/query conn "select name from t1 where name is null")
    (pdo/fetch-column 0 :eof))
;; => nil      ; a row, whose column was NULL
```

## Large result sets

Building a map per row is the dominant cost of reading a big result set — it is
~160x the raw `PDO::fetchAll` floor on 20k rows. When you are summing a column,
writing a CSV, or feeding a chart, you never wanted the maps:

```clojure
(pdo/fetch-all (pdo/query conn "select id, name from big") {:as :rows})
;; => {:cols [:id :name]
;;     :rows [[1 "phel"] [2 "php"] ...]}
```

On 20k rows × 5 columns that is **868 ms → 172 ms**, about 5x. Column order
matches the `select` list, and `:cols` is correct even when `:rows` is empty.

Summing one column, without ever building a row map:

```clojure
(let [{:cols cols, :rows rows} (pdo/fetch-all stmt {:as :rows})
      i (php/array_search :total (phel->php cols))]
  (reduce + 0 (map (fn [r] (get r i)) rows)))
```

For result sets too large to hold at once, `pdo/statement-seq` streams them one
row at a time. It always yields maps — pair it with `pdo/column-names` if you
need the column list up front.

## Param types

Types are inferred from the value, so you rarely need to say anything:

| Phel value | PDO type |
|---|---|
| `nil` | `PARAM_NULL` |
| `true` / `false` | `PARAM_BOOL` |
| an integer | `PARAM_INT` |
| everything else (strings, floats) | `PARAM_STR` |

This applies to `bind-value`, `bind-param` and the params you hand to `execute`
alike. Floats stay `PARAM_STR` - PDO has no `PARAM_FLOAT`, and `PARAM_STR` is the
lossless choice for them.

Inference matters most under **emulated prepares**, which is PDO's default for
MySQL. There PDO interpolates the value itself, and `PARAM_STR` quotes it:

```sql
select * from t1 limit '10'   -- syntax error on MySQL
where id = '10'               -- valid, but defeats an integer index
```

### Overriding

Pass an explicit type when you know better than the inference - a numeric string
that must stay a string, say, or a `PARAM_LOB` stream:

```clojure
(-> (pdo/prepare conn "select * from t1 where zip = :zip")
    (pdo/bind-value :zip "01234" \PDO/PARAM_STR)
    (pdo/execute)
    (pdo/fetch))
```

Available types: `\PDO/PARAM_STR`, `\PDO/PARAM_INT`, `\PDO/PARAM_BOOL`,
`\PDO/PARAM_NULL`, `\PDO/PARAM_LOB`.

## Transactions

Use `with-transaction` to bracket a body: it commits on success (returning the
last body value) and rolls back + re-throws on any exception.

```clojure
(pdo/with-transaction conn
  (pdo/insert conn :accounts {:name "a", :balance 100})
  (pdo/insert conn :accounts {:name "b", :balance 0}))
```

### Nesting

PDO cannot nest `beginTransaction`, so when `conn` is already in a transaction
`with-transaction` brackets the body with a `SAVEPOINT` instead. A nested block
that fails undoes only its own writes:

```clojure
(pdo/with-transaction conn
  (pdo/insert conn :accounts {:name "a"})
  (try
    (pdo/with-transaction conn
      (pdo/insert conn :accounts {:name "b"})
      (throw (php/new \Exception "boom")))
    (catch \Throwable _e :skipped)))
;; => the "a" row is committed; the "b" row is not
```

An *uncaught* throw still propagates outward and rolls the whole transaction
back, so the outer guarantee is unchanged.

Savepoint names are generated internally and never taken from caller input -
they are SQL identifiers and cannot be bound as parameters. This needs a driver
with `SAVEPOINT` support; SQLite, MySQL/InnoDB and PostgreSQL all qualify.

`pdo/with-savepoint` exposes the same primitive directly when you want a
savepoint without the surrounding `with-transaction`:

```clojure
(pdo/with-savepoint conn (fn [] (pdo/insert conn :accounts {:name "c"})))
```

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
sequences; `php/intval` it when you need a number. On PostgreSQL pass the
sequence name to raw PDO: `(php/-> (conn :pdo) (lastInsertId "seq"))`.

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
;; => {:id 1, :name "phel"}
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
