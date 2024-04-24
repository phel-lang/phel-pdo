# phel-pdo

phel-lang pdo wrapper library.

## Usage

This is an example of connecting to a file database, creating a table, inserting records, and searching on repl.

```
phel:1> (require smeghead\pdo)
smeghead\pdo
phel:2> (require smeghead\pdo\statement)
smeghead\pdo\statement
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


## Development

### Open shell

```bash
docker compose build
docker compose run --rm php_cli bash
```

### Test

```bash
# vendor/bin/phel test
```

