import backend/context
import backend/log
import backend/migration
import backend/sql
import backend/types.{
  type Context, type DatabaseMsg, type Logger, DatabaseStop, DatabaseVideoFetch,
  DatabaseVideoFetchAll, DatabaseVideoInsert,
}
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/json
import gleam/option.{type Option}
import gleam/otp/actor
import gleam/otp/supervision
import gleam/result
import middle/author
import middle/id.{type Id}
import middle/timestamp
import middle/video.{type Video}

pub opaque type Builder {
  Builder(name: Option(process.Name(DatabaseMsg)), path: String, logger: Logger)
}

pub fn new() {
  Builder(path: ":memory:", name: option.None, logger: log.default_logger)
}

pub fn path(builder: Builder, path: String) {
  Builder(..builder, path:)
}

pub fn named(builder: Builder, name) {
  Builder(..builder, name: option.Some(name))
}

pub fn logger(builder: Builder, logger: Logger) {
  Builder(..builder, logger:)
}

pub fn start(builder: Builder) {
  let ctx = context.new("database", "", builder.logger, process.new_subject())

  let db =
    sql.open(ctx, builder.path)
    |> result.replace_error(actor.InitFailed(
      "could not open database file: " <> builder.path,
    ))
  use db <- result.try(db)

  let result =
    migration.migrate(ctx, db)
    |> result.replace_error(actor.InitFailed("could not migrate database"))
  use _ <- result.try(result)

  let actor =
    actor.new(db)
    |> actor.on_message(fn(conn, msg) { on_message(ctx, conn, msg) })

  let actor = case builder.name {
    option.Some(name) -> actor |> actor.named(name)
    option.None -> actor
  }

  actor
  |> actor.start()
}

pub fn on_message(ctx, db, msg: DatabaseMsg) {
  case msg {
    DatabaseStop -> {
      log.info(ctx, "db: closing actor")
      let _ =
        sql.close(ctx, db)
        |> log.error_on_error(ctx, "db: failed to close database")
      actor.stop()
    }
    DatabaseVideoFetchAll(reply_to:) -> {
      let videos = video_fetch_all_internal(ctx, db)
      actor.send(reply_to, videos)
      actor.continue(db)
    }
    DatabaseVideoInsert(video:, reply_to:) -> {
      video_insert_internal(ctx, db, video)
      |> actor.send(reply_to, _)

      actor.continue(db)
    }
    DatabaseVideoFetch(reply_to:, id:) -> {
      video_fetch_internal(ctx, db, id)
      |> actor.send(reply_to, _)
      actor.continue(db)
    }
  }
}

pub fn supervised(builder) {
  fn() { start(builder) }
  |> supervision.worker()
}

fn video_fetch_all_internal(ctx, db) {
  log.info(ctx, "db: fetching all videos")
  "
  SELECT 
    id, 
    author_name, 
    title, 
    thumbnail_url, 
    author_url, 
    timestamp 
  FROM video 
  ORDER BY timestamp ASC;
  "
  |> sql.query()
  |> sql.returning({
    use id <- decode.field(0, id.decoder())
    use author_name <- decode.field(1, decode.string)
    use title <- decode.field(2, decode.string)
    use thumbnail <- decode.field(3, decode.string)
    use author_url <- decode.field(4, decode.string)
    use timestamp <- decode.field(5, timestamp.decoder())

    let author = author.Author(name: author_name, url: author_url)
    video.Video(id:, author:, title:, thumbnail:, timestamp:)
    |> decode.success
  })
  |> sql.fetch(ctx, db)
}

fn video_insert_internal(ctx, db, video: Video) {
  log.info(ctx, "db: inserting video " <> json.to_string(video.to_json(video)))
  "
  INSERT INTO video (
    id,
    author_name,
    author_url,
    title,
    thumbnail_url,
    timestamp
  ) VALUES (
    ?, ?, ?, ?, ?, ?
  );
  "
  |> sql.query()
  |> sql.parameter(video.id |> id.to_string |> sql.text)
  |> sql.parameter(video.author.name |> sql.text)
  |> sql.parameter(video.author.url |> sql.text)
  |> sql.parameter(video.title |> sql.text)
  |> sql.parameter(video.thumbnail |> sql.text)
  |> sql.parameter(video.timestamp |> timestamp.to_int |> sql.int)
  |> sql.execute(ctx, db)
}

fn video_fetch_internal(ctx, db, id: Id(Video)) {
  log.info(ctx, "db: fetching video: " <> id.to_string(id))
  "
  SELECT author_url, author_name, title, thumbnail_url, timestamp FROM video 
  WHERE id = ? LIMIT 1;
  "
  |> sql.query()
  |> sql.parameter(id |> id.to_string |> sql.text)
  |> sql.returning({
    use author_url <- decode.field(0, decode.string)
    use author_name <- decode.field(1, decode.string)
    use title <- decode.field(2, decode.string)
    use thumbnail <- decode.field(3, decode.string)
    use timestamp <- decode.field(4, timestamp.decoder())

    let author = author.Author(name: author_name, url: author_url)
    video.Video(id:, author:, title:, thumbnail:, timestamp:)
    |> decode.success()
  })
  |> sql.fetch_one(ctx, db)
}

pub fn video_insert(ctx: Context, video: Video) {
  actor.call(ctx.database, 20_000, DatabaseVideoInsert(reply_to: _, video:))
}

pub fn video_fetch_all(ctx: Context) {
  actor.call(ctx.database, 20_000, DatabaseVideoFetchAll(reply_to: _))
}

pub fn video_fetch(ctx: Context, id: Id(Video)) {
  actor.call(ctx.database, 20_000, DatabaseVideoFetch(reply_to: _, id:))
}
