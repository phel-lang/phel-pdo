# phel-pdo

phel-lang pdo wrapper library.

## Description


Inherently, it is very easy to call the functionality of PHP classes from phel code. Therefore, it is not difficult to access the database using PDO directly.

However, if you have to think about PHP classes while writing phel code, there is a concern that a context switch will occur between the phel world and the PHP world, and you will not be able to concentrate on writing the phel code.

Therefore, I created a wrapper library (phel-pdo) that can handle PDO just by calling Phel functions.

## Install

Install from composer. https://packagist.org/packages/phel-lang/phel-pdo

```bash
composer require phel-lang/phel-pdo
```

## Usage

This is an example of connecting to a file database, creating a table, inserting records, and searching on repl.

```clojure
phel:1> (require phel\pdo)
phel\pdo
phel:2> (require phel\pdo\statement)
phel\pdo\statement
phel:3> (def connection-string "sqlite:database.db")
1
phel:4> (def conn (pdo/connect connection-string))
1
phel:5> (pdo/exec conn "create table t1 (id integer primary key autoincrement, name varchr(10))")
0
phel:6> (pdo/exec conn "insert into t1 (name) values ('phel'), ('php')")
2
phel:7> (def stmt (pdo/query conn "select * from t1 where id = 1"))
1
phel:8> (statement/fetch stmt)
{:id 1 :name phel}
phel:8> (def stmt (pdo/prepare conn "select * from t1 where id = :id"))
1
phel:9> (def stmt (statement/execute stmt {:id 1}))
1
phel:10> (statement/fetch stmt)
{:id 1 :name phel}
```

## Reference

### pdo

Represents a connection between PHP and a database server.

####  begin

Initiates a transaction

```clojure
(begin conn)
```

####  commit

Commits a transaction

```clojure
(commit conn)
```

####  connect

Connect database and return connection object.
Throws a PDOException if the attempt to connect to the requested database fails

```clojure
(connect dns & [username password options])
```

####  error-code

Fetch the SQLSTATE associated with the last operation on the database handle

```clojure
(error-code conn)
```

####  error-info

Fetch extended error information associated with the last operation on the database handle

```clojure
(error-info conn)
```

####  exec

Execute an SQL statement and return the number of affected rows

```clojure
(exec conn stmt & [fetch-mode])
```

####  get-attribute

Retrieve a database connection attribute

```clojure
(get-attribute conn attribute)
```

####  get-available-drivers

Return an array of available PDO drivers

```clojure
(get-available-drivers conn)
```

####  in-transaction

Checks if inside a transaction

```clojure
(in-transaction conn)
```

####  last-insert-id

Returns the ID of the last inserted row or sequence value

```clojure
(last-insert-id conn)
```

####  prepare

Prepares a statement for execution and returns a statement object

```clojure
(prepare conn stmt & [fetch-mode])
```

####  query

Prepares and executes an SQL statement without placeholders

```clojure
(query conn stmt & [fetch-mode])
```

####  quote

Quotes a string for use in a query

```clojure
(query conn string & [type])
```

####  rollback

Rolls back a transaction

```clojure
(rollback conn)
```

####  set-attribute

Set an attribute

```clojure
(set-attribute conn attribute value)
```

### statement

Represents a prepared statement and, after the statement is executed, an associated result set.

#### bind-value

Binds a value to a parameter

```clojure
(bind-value statement column value & [type])
```

#### debug-dump-params

Returns an SQL prepared command

```clojure
(debug-dump-params statement)
```

#### execute

Executes a prepared statement

```clojure
(execute statement)
```

#### fetch

Fetches the next row from a result set

```clojure
(fetch statement)
```

#### fetch-all

Fetches the remaining rows from a result set

```clojure
(fetch-all statement)
```

#### fetch-column

Returns a single column from the next row of a result set

```clojure
(fetch-column statement & [column])
```


## Development

### Open shell

```bash
docker compose build
docker compose run --rm php_cli bash
```

### Test

```bash
vendor/bin/phel test
```
