import backend/db_actor
import gleam/list
import gleam/otp/actor
import gleam/string
import middle/author
import middle/video

pub fn start_test() {
  let assert Ok(db) =
    db_actor.new()
    |> db_actor.path(":memory:")
    |> db_actor.start()
  let db = db.data

  actor.send(db, db_actor.Stop)
}

fn with_db(handler) {
  let assert Ok(db) =
    db_actor.new()
    |> db_actor.path(":memory:")
    |> db_actor.start()

  let _ = handler(db.data)

  actor.send(db.data, db_actor.Stop)
}

pub fn fetch_all_000_test() {
  use db <- with_db()

  let assert Ok(out) = actor.call(db, 3000, db_actor.VideoFetchAll)
  assert out == []
}

pub fn fetch_all_001_test() {
  use db <- with_db()

  let video =
    video.Video(
      id: video.Id("someid"),
      author: author.Author(name: "Gustav", url: "url"),
      title: "This is a title",
      url: "https://youtu.be/someid",
      thumbnail: "anohter url",
      timestamp: video.get_timestamp(),
    )

  let assert Ok(_) =
    actor.call(db, 3000, db_actor.VideoInsert(reply_to: _, video:))

  let assert Ok(out) = actor.call(db, 3000, db_actor.VideoFetchAll)
  assert out == [video]
}

pub fn fetch_all_002_test() {
  use db <- with_db()

  let video0 =
    video.Video(
      id: video.Id("someid"),
      author: author.Author(name: "Gustav", url: "url"),
      title: "This is a title",
      url: "https://youtu.be/someid",
      thumbnail: "anohter url",
      timestamp: video.get_timestamp(),
    )

  let video1 =
    video.Video(
      id: video.Id("otherid"),
      author: author.Author(name: "Bernhadrd", url: "url0"),
      title: "This is a title other title",
      url: "https://youtu.be/otherid",
      thumbnail: "anohter url1",
      timestamp: video.get_timestamp(),
    )

  let assert Ok(_) =
    actor.call(db, 3000, db_actor.VideoInsert(reply_to: _, video: video0))
  let assert Ok(_) =
    actor.call(db, 3000, db_actor.VideoInsert(reply_to: _, video: video1))

  let assert Ok(out) = actor.call(db, 3000, db_actor.VideoFetchAll)
  let out =
    out |> list.sort(fn(a, b) { string.compare(a.id.inner, b.id.inner) })
  let expected =
    [video0, video1]
    |> list.sort(fn(a, b) { string.compare(a.id.inner, b.id.inner) })
  assert out == expected
}

pub fn fetch_000_test() {
  use db <- with_db()

  let assert Error(_) =
    actor.call(db, 3000, db_actor.VideoFetch(
      reply_to: _,
      id: video.Id("someid"),
    ))
}

pub fn fetch_001_test() {
  use db <- with_db()

  let video =
    video.Video(
      id: video.Id("someid"),
      author: author.Author(name: "Gustav", url: "url"),
      title: "This is a title",
      url: "https://youtu.be/someid",
      thumbnail: "anohter url",
      timestamp: video.get_timestamp(),
    )

  let assert Ok(_) =
    actor.call(db, 3000, db_actor.VideoInsert(reply_to: _, video:))

  let assert Ok(out) =
    actor.call(db, 3000, db_actor.VideoFetch(
      reply_to: _,
      id: video.Id("someid"),
    ))
  assert out == video
}

pub fn fetch_002_test() {
  use db <- with_db()

  let video0 =
    video.Video(
      id: video.Id("someid"),
      author: author.Author(name: "Gustav", url: "url"),
      title: "This is a title",
      url: "https://youtu.be/someid",
      thumbnail: "anohter url",
      timestamp: video.get_timestamp(),
    )

  let video1 =
    video.Video(
      id: video.Id("otherid"),
      author: author.Author(name: "Bernhadrd", url: "url0"),
      title: "This is a title other title",
      url: "https://youtu.be/otherid",
      thumbnail: "anohter url1",
      timestamp: video.get_timestamp(),
    )

  let assert Ok(_) =
    actor.call(db, 3000, db_actor.VideoInsert(reply_to: _, video: video0))
  let assert Ok(_) =
    actor.call(db, 3000, db_actor.VideoInsert(reply_to: _, video: video1))

  let assert Ok(out) =
    actor.call(db, 3000, db_actor.VideoFetch(
      reply_to: _,
      id: video.Id("otherid"),
    ))
  assert out == video1
}
