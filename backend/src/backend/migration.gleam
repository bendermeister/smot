import backend/log
import backend/sql
import gleam/bool
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/result
import sqlight

pub fn migrate(conn: sqlight.Connection) {
  let level =
    get_level(conn)
    |> log.on_error("migration: could not get current migration level")
  use level <- result.try(level)

  let result =
    migrations
    |> list.drop(level)
    |> list.index_map(fn(x, i) { #(x, i) })
    |> list.fold_until(Ok(Nil), fn(_, migration) {
      let #(migration, index) = migration
      log.info("migration: running: " <> int.to_string(index))

      migration(conn)
      |> log.on_error("migration: migration failed")
      |> result.replace(list.Continue(Ok(Nil)))
      |> result.unwrap(list.Stop(Error(Nil)))
    })
    |> log.on_error("migration: migrations: failed")
  use _ <- result.try(result)

  "UPDATE migration SET level = ?;"
  |> sql.query()
  |> sql.parameter(migrations |> list.length |> sql.int)
  |> sql.execute(conn)
  |> log.on_error("migration: failed to update migration level in database")
}

const migrations = [
  migration_0000,
  migration_0001,
  migration_0002,
  migration_0003,
]

fn has_migration_table(conn: sqlight.Connection) {
  "SELECT EXISTS (SELECT name FROM sqlite_master WHERE type='table' AND name='migration');"
  |> sql.query()
  |> sql.returning(decode.field(0, sql.decode_bool(), decode.success))
  |> sql.fetch_one(conn)
}

fn get_level(conn: sqlight.Connection) {
  let has_migration_table = has_migration_table(conn)
  use has_migration_table <- result.try(has_migration_table)
  use <- bool.guard(when: !has_migration_table, return: Ok(0))

  "SELECT level FROM migration LIMIT 1;"
  |> sql.query()
  |> sql.returning({
    use level <- decode.field(0, decode.int)
    level |> decode.success
  })
  |> sql.fetch_one(conn)
}

fn migration_0000(conn: sqlight.Connection) {
  "
  CREATE TABLE migration (
    level INT NOT NULL
  );
  "
  |> sql.query()
  |> sql.execute(conn)
}

fn migration_0001(conn) {
  "INSERT INTO migration (level) VALUES(0);"
  |> sql.query()
  |> sql.execute(conn)
}

fn migration_0002(conn) {
  " 
  CREATE TABLE video (
      id            TEXT NOT NULL UNIQUE,
      title         TEXT NOT NULL,
      author_name   TEXT NOT NULL,
      author_url    TEXT NOT NULL,
      thumbnail_url TEXT NOT NULL,

      PRIMARY KEY(id)
  );
  "
  |> sql.query()
  |> sql.execute(conn)
}

fn migration_0003(conn) {
  "
  ALTER TABLE video ADD COLUMN timestamp INT NOT NULL;
  "
  |> sql.query()
  |> sql.execute(conn)
}
