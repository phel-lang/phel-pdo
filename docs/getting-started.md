# Getting started

## Requirements

- PHP `>=8.4` with the PDO extension and the driver you target (`pdo_sqlite`, `pdo_mysql`, `pdo_pgsql`, …).
- [Composer](https://getcomposer.org/).
- [Phel](https://phel-lang.org) `^0.41` (pulled in transitively).

Check your PDO drivers:

```bash
php -r 'print_r(PDO::getAvailableDrivers());'
```

## Install

```bash
composer require phel-lang/phel-pdo
```

## First query (60 seconds)

```clojure
(require phel.pdo)

(def conn (pdo/connect "sqlite::memory:"))
(pdo/exec conn "create table t1 (id integer primary key autoincrement, name varchar(10))")
(pdo/exec conn "insert into t1 (name) values ('phel'), ('php')")

(-> (pdo/query conn "select * from t1")
    (pdo/fetch-all))
;; => [{:id 1, :name "phel"} {:id 2, :name "php"}]
```

That's the whole mental model:

1. `pdo/connect` returns a `connection` struct.
2. `pdo/query` / `pdo/prepare` return a `statement` struct.
3. Fetches return Phel maps (keys are keywords).
4. Mutators (`execute`, `bind-value`, `set-attribute`) return their struct so they thread.

## Connecting to a real DB

```clojure
;; MySQL
(pdo/connect "mysql:host=127.0.0.1;dbname=app;charset=utf8mb4" "user" "secret")

;; PostgreSQL
(pdo/connect "pgsql:host=127.0.0.1;dbname=app" "user" "secret")

;; SQLite file
(pdo/connect "sqlite:./app.db")
```

`connect` accepts the same DSN strings as `\PDO::__construct`. See the [PHP PDO drivers page](https://www.php.net/manual/en/pdo.drivers.php) for the full DSN grammar per driver.

## Run the test suite

```bash
composer install
composer test            # = vendor/bin/phel test
```

Tests run against `sqlite::memory:` - no setup, no fixtures to load.

## Where to go next

- **[Recipes](recipes.md)** - prepared statements, transactions, bind types, phel-sql.
- **[Architecture](architecture.md)** - why the wrapper looks the way it does.
- **[Troubleshooting](troubleshooting.md)** - when something blows up.
