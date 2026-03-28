import backend/log
import backend/sql
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/json
import gleam/otp/actor
import gleam/otp/supervision
import gleam/result
import middle/author
import middle/video

pub type Msg {
  Stop
  VideoFetchAll(reply_to: process.Subject(Result(List(video.Video), Nil)))
  VideoInsert(video: video.Video, reply_to: process.Subject(Result(Nil, Nil)))
  VideoFetch(reply_to: process.Subject(Result(video.Video, Nil)), id: video.Id)
}

pub fn start(name: process.Name(Msg), db: String) {
  let db =
    sql.open(db)
    |> result.replace_error(actor.InitFailed(
      "could not open database file: " <> db,
    ))
  use db <- result.try(db)

  actor.new(db)
  |> actor.named(name)
  |> actor.on_message(on_message)
  |> actor.start()
}

pub fn on_message(db, msg: Msg) {
  case msg {
    Stop -> {
      log.info("db: closing actor")
      let _ =
        sql.close(db)
        |> log.on_error("db: failed to close database")
      actor.stop()
    }
    VideoFetchAll(reply_to:) -> {
      let videos = video_fetch_all(db)
      actor.send(reply_to, videos)
      actor.continue(db)
    }
    VideoInsert(video:, reply_to:) -> {
      video_insert(db, video)
      |> actor.send(reply_to, _)

      actor.continue(db)
    }
    VideoFetch(reply_to:, id:) -> {
      video_fetch(db, id)
      |> actor.send(reply_to, _)
      actor.continue(db)
    }
  }
}

pub fn supervised(name, db) {
  fn() { start(name, db) }
  |> supervision.worker()
}

fn video_fetch_all(db) {
  log.info("db: fetching all videos")
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
    use id <- decode.field(0, video.id_decoder())
    use author_name <- decode.field(1, decode.string)
    use title <- decode.field(2, decode.string)
    use thumbnail <- decode.field(3, decode.string)
    use author_url <- decode.field(4, decode.string)
    use timestamp <- decode.field(5, video.timestamp_decoder())
    let url = video.id_to_url(id)

    let author = author.Author(name: author_name, url: author_url)
    video.Video(id:, author:, title:, url:, thumbnail:, timestamp:)
    |> decode.success
  })
  |> sql.fetch(db)
}

fn video_insert(db, video: video.Video) {
  log.info("db: inserting video " <> json.to_string(video.to_json(video)))
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
  |> sql.parameter(video.id.inner |> sql.text)
  |> sql.parameter(video.author.name |> sql.text)
  |> sql.parameter(video.author.url |> sql.text)
  |> sql.parameter(video.title |> sql.text)
  |> sql.parameter(video.thumbnail |> sql.text)
  |> sql.parameter(video.timestamp.inner |> sql.int)
  |> sql.execute(db)
}

fn video_fetch(db, id: video.Id) {
  log.info("db: fetching video: " <> id.inner)
  "
  SELECT author_url, author_name, title, thumbnail_url, timestamp FROM video 
  WHERE id = ? LIMIT 1;
  "
  |> sql.query()
  |> sql.parameter(id.inner |> sql.text)
  |> sql.returning({
    use author_url <- decode.field(0, decode.string)
    use author_name <- decode.field(1, decode.string)
    use title <- decode.field(2, decode.string)
    use thumbnail <- decode.field(3, decode.string)
    use timestamp <- decode.field(4, video.timestamp_decoder())

    let url = video.id_to_url(id)
    let author = author.Author(name: author_name, url: author_url)
    video.Video(id:, author:, title:, url:, thumbnail:, timestamp:)
    |> decode.success()
  })
  |> sql.fetch_one(db)
}
