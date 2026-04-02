import backend/db
import gleam/list
import middle/author
import middle/id.{Id}
import middle/timestamp
import middle/video

import util.{with_db}

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

  let assert Ok(_) = db.video_upsert(ctx, video)

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

  let assert Ok(_) = db.video_upsert(ctx, video0)
  let assert Ok(_) = db.video_upsert(ctx, video1)

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

  let assert Ok(_) = db.video_upsert(ctx, video)
  let assert Ok(out) = db.video_fetch(ctx, Id("someid"))
  assert out == video
}

pub fn fetch_002_test() {
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
      id: Id("otherid"),
      author: author.Author(name: "Bernhadrd", url: "url0"),
      title: "This is a title other title",
      thumbnail: "anohter url1",
      timestamp: timestamp.now(),
      tags: ["these", "are", "tags"],
    )

  let assert Ok(_) = db.video_upsert(ctx, video0)
  let assert Ok(_) = db.video_upsert(ctx, video1)
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

  let assert Ok(_) = db.video_upsert(ctx, video0)
  let assert Ok(_) = db.video_upsert(ctx, video1)
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
  let assert Ok(_) = db.video_upsert(ctx, video)
  let assert Ok(_) = db.video_fetch(ctx, Id("someid"))
  let assert Ok(_) = db.video_delete(ctx, Id("someid"))
  let assert Error(_) = db.video_fetch(ctx, Id("someid"))
}

pub fn upsert_000_test() {
  use ctx <- util.with_db

  let video =
    video.Video(
      id: Id("someid"),
      author: author.Author(name: "Gustav", url: "url"),
      title: "This is a title",
      thumbnail: "anohter url",
      timestamp: timestamp.now(),
      tags: ["hello", "world"],
    )

  let assert Ok(_) = db.video_upsert(ctx, video)
  let assert Ok(out) = db.video_fetch(ctx, video.id)
  assert video == out

  let assert Ok(_) = db.video_upsert(ctx, video)
  let assert Ok(out) = db.video_fetch(ctx, video.id)
  assert video == out

  let video = video.Video(..video, title: "this is some other title")

  let assert Ok(_) = db.video_upsert(ctx, video)
  let assert Ok(out) = db.video_fetch(ctx, video.id)
  assert video == out
}
