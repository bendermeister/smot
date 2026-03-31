import backend/log
import backend/sql
import gleam/bool
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/result
import sqlight

pub fn migrate(ctx, conn: sqlight.Connection) {
  let level =
    get_level(ctx, conn)
    |> log.info_on_error(
      ctx,
      "migration: could not get current migration level",
    )
  use level <- result.try(level)

  let result =
    migrations
    |> list.drop(level)
    |> list.index_map(fn(x, i) { #(x, i) })
    |> list.fold_until(Ok(Nil), fn(_, migration) {
      let #(migration, index) = migration
      log.info(ctx, "migration: running: " <> int.to_string(index))

      migration(ctx, conn)
      |> log.info_on_error(ctx, "migration: migration failed")
      |> result.replace(list.Continue(Ok(Nil)))
      |> result.unwrap(list.Stop(Error(Nil)))
    })
    |> log.info_on_error(ctx, "migration: migrations: failed")
  use _ <- result.try(result)

  "UPDATE migration SET level = ?;"
  |> sql.query()
  |> sql.parameter(migrations |> list.length |> sql.int)
  |> sql.execute(ctx, conn)
  |> log.info_on_error(
    ctx,
    "migration: failed to update migration level in database",
  )
}

const migrations = [
  migration_0000,
  migration_0001,
  migration_0002,
  migration_0003,
  migration_0004,
]

fn has_migration_table(ctx, conn: sqlight.Connection) {
  "SELECT EXISTS (SELECT name FROM sqlite_master WHERE type='table' AND name='migration');"
  |> sql.query()
  |> sql.returning(decode.field(0, sql.decode_bool(), decode.success))
  |> sql.fetch_one(ctx, conn)
}

fn get_level(ctx, conn: sqlight.Connection) {
  let has_migration_table = has_migration_table(ctx, conn)
  use has_migration_table <- result.try(has_migration_table)
  use <- bool.guard(when: !has_migration_table, return: Ok(0))

  "SELECT level FROM migration LIMIT 1;"
  |> sql.query()
  |> sql.returning({
    use level <- decode.field(0, decode.int)
    level |> decode.success
  })
  |> sql.fetch_one(ctx, conn)
}

fn migration_0000(ctx, conn: sqlight.Connection) {
  "
  CREATE TABLE migration (
    level INT NOT NULL
  );
  "
  |> sql.query()
  |> sql.execute(ctx, conn)
}

fn migration_0001(ctx, conn) {
  "INSERT INTO migration (level) VALUES(0);"
  |> sql.query()
  |> sql.execute(ctx, conn)
}

fn migration_0002(ctx, conn) {
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
  |> sql.execute(ctx, conn)
}

fn migration_0003(ctx, conn) {
  "
  ALTER TABLE video ADD COLUMN timestamp INT NOT NULL;
  "
  |> sql.query()
  |> sql.execute(ctx, conn)
}

fn migration_0004(ctx, conn) {
  "
  ALTER TABLE video ADD COLUMN tags TEXT;
  "
  |> sql.query()
  |> sql.execute(ctx, conn)
}
