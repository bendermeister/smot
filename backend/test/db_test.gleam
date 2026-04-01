import backend/context
import backend/db
import backend/log
import backend/types.{DatabaseStop}
import gleam/list
import gleam/otp/actor
import middle/author
import middle/id.{Id}
import middle/timestamp
import middle/video

pub fn with_db_logger(handler) {
  let logger = log.default_logger

  let assert Ok(db) =
    db.new()
    |> db.path(":memory:")
    |> db.logger(logger)
    |> db.start()

  let ctx = context.new("test", "", logger, db.data)

  let _ = handler(ctx)

  actor.send(db.data, DatabaseStop)
}

fn with_db(handler) {
  // let logger = log.default_logger
  let logger = fn(_) { Nil }

  let assert Ok(db) =
    db.new()
    |> db.path(":memory:")
    |> db.logger(logger)
    |> db.start()

  let ctx = context.new("test", "", logger, db.data)

  let _ = handler(ctx)

  actor.send(db.data, DatabaseStop)
}

pub fn fetch_all_000_test() {
  use ctx <- with_db()

  let assert Ok(out) = db.video_fetch_all(ctx)
  assert out == []
}

pub fn fetch_all_001_test() {
  use ctx <- with_db()

  let video =
    video.Video(
      id: Id("someid"),
      author: author.Author(name: "Gustav", url: "url"),
      title: "This is a title",
      thumbnail: "anohter url",
      timestamp: timestamp.now(),
      tags: ["tag"],
    )

  let assert Ok(_) = db.video_insert(ctx, video)

  let assert Ok(out) = db.video_fetch_all(ctx)
  assert out == [video]
}

pub fn fetch_all_002_test() {
  use ctx <- with_db()

  let video0 =
    video.Video(
      id: Id("someid"),
      author: author.Author(name: "Gustav", url: "url"),
      title: "This is a title",
      thumbnail: "anohter url",
      timestamp: timestamp.now(),
      tags: [],
    )

  let video1 =
    video.Video(
      id: Id("otherid"),
      author: author.Author(name: "Bernhadrd", url: "url0"),
      title: "This is a title other title",
      thumbnail: "anohter url1",
      timestamp: timestamp.now(),
      tags: ["tag"],
    )

  let assert Ok(_) = db.video_insert(ctx, video0)
  let assert Ok(_) = db.video_insert(ctx, video1)

  let assert Ok(out) = db.video_fetch_all(ctx)

  let out = out |> list.sort(fn(a, b) { id.compare(a.id, b.id) })
  let expected =
    [video0, video1]
    |> list.sort(fn(a, b) { id.compare(a.id, b.id) })
  assert out == expected
}

pub fn fetch_000_test() {
  use ctx <- with_db()
  let assert Error(_) = db.video_fetch(ctx, Id("something"))
}

pub fn fetch_001_test() {
  use ctx <- with_db()

  let video =
    video.Video(
      id: Id("someid"),
      author: author.Author(name: "Gustav", url: "url"),
      title: "This is a title",
      thumbnail: "anohter url",
      timestamp: timestamp.now(),
      tags: [],
    )

  let assert Ok(_) = db.video_insert(ctx, video)
  let assert Ok(out) = db.video_fetch(ctx, Id("someid"))
  assert out == video
}

pub fn fetch_002_test() {
  use ctx <- with_db()

  let video0 =
    video.Video(
      id: Id("someid"),
      author: author.Author(name: "Gustav", url: "url"),
      title: "This is a title",
      thumbnail: "anohter url",
      timestamp: timestamp.now(),
      tags: ["hello", "world"],
    )

  let video1 =
    video.Video(
      id: Id("otherid"),
      author: author.Author(name: "Bernhadrd", url: "url0"),
      title: "This is a title other title",
      thumbnail: "anohter url1",
      timestamp: timestamp.now(),
      tags: ["these", "are", "tags"],
    )

  let assert Ok(_) = db.video_insert(ctx, video0)
  let assert Ok(_) = db.video_insert(ctx, video1)
  let assert Ok(out) = db.video_fetch(ctx, Id("otherid"))
  assert out == video1
}

pub fn update_000_test() {
  use ctx <- with_db

  let video0 =
    video.Video(
      id: Id("someid"),
      author: author.Author(name: "Gustav", url: "url"),
      title: "This is a title",
      thumbnail: "anohter url",
      timestamp: timestamp.now(),
      tags: ["hello", "world"],
    )

  let video1 =
    video.Video(
      id: Id("someid"),
      author: author.Author(name: "Bernhadrd", url: "url0"),
      title: "This is a title other title",
      thumbnail: "anohter url1",
      timestamp: timestamp.now(),
      tags: ["these", "are", "tags"],
    )

  let assert Ok(_) = db.video_insert(ctx, video0)
  let assert Ok(_) = db.video_update(ctx, video1)
  let assert Ok(out) = db.video_fetch(ctx, Id("someid"))

  assert out == video1
}

pub fn delete_000_test() {
  use ctx <- with_db

  let video =
    video.Video(
      id: Id("someid"),
      author: author.Author(name: "Gustav", url: "url"),
      title: "This is a title",
      thumbnail: "anohter url",
      timestamp: timestamp.now(),
      tags: ["hello", "world"],
    )

  let assert Error(_) = db.video_fetch(ctx, Id("someid"))
  let assert Ok(_) = db.video_insert(ctx, video)
  let assert Ok(_) = db.video_fetch(ctx, Id("someid"))
  let assert Ok(_) = db.video_delete(ctx, Id("someid"))
  let assert Error(_) = db.video_fetch(ctx, Id("someid"))
}
