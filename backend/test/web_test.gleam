import backend/db
import backend/types.{YoutubeFetchVideo}
import backend/web
import gleam/http
import gleam/json
import gleam/otp/actor
import middle/author.{Author}
import middle/id.{Id}
import middle/timestamp
import middle/video.{Video}
import util.{with_db}
import wisp
import wisp/simulate

const id = Id("someid")

fn with_yt_actor() {
  let assert Ok(actor) =
    actor.new(Nil)
    |> actor.on_message(fn(_, msg) {
      let YoutubeFetchVideo(reply_to:, id:) = msg

      Video(
        id:,
        author: author.Author(name: "Some Name", url: "https://somename.com"),
        title: "This is a title",
        thumbnail: "https://thumbnail.org",
        timestamp: timestamp.now(),
        tags: [],
      )
      |> Ok
      |> actor.send(reply_to, _)

      actor.continue(Nil)
    })
    |> actor.start()
  actor.data
}

const video = Video(
  id:,
  author: Author(name: "name", url: "url"),
  title: "title",
  thumbnail: "thumbnail",
  timestamp: timestamp.TimeStamp(1234),
  tags: [],
)

const other_video = Video(
  id:,
  author: Author(name: "other name", url: "other url"),
  title: "other title",
  thumbnail: "other thumbnail",
  timestamp: timestamp.TimeStamp(5678),
  tags: ["other", "tags"],
)

pub fn video_update_000_test() {
  use ctx <- with_db
  let yt = with_yt_actor()

  let out =
    simulate.browser_request(http.Post, "/api/video/update")
    |> web.on_request(ctx, _, yt)

  let expected = wisp.bad_request("Invalid JSON")

  assert out == expected
}

pub fn video_update_001_test() {
  use ctx <- with_db
  let yt = with_yt_actor()

  let data =
    [#("entry", json.int(1)), #("second", json.string("Hello World"))]
    |> json.object()

  let out =
    simulate.browser_request(http.Post, "/api/video/update")
    |> simulate.json_body(data)
    |> web.on_request(ctx, _, yt)

  let expected = wisp.bad_request("Invalid JSON")

  assert out == expected
}

pub fn video_update_003_test() {
  use ctx <- with_db
  let id = Id("someid")
  let yt = with_yt_actor()

  let assert Ok(_) = db.video_upsert(ctx, video)

  let out =
    simulate.browser_request(http.Post, "/api/video/update")
    |> simulate.json_body(other_video |> video.to_json)
    |> web.on_request(ctx, _, yt)

  let expected = wisp.ok()

  assert out == expected

  let assert Ok(out) = db.video_fetch(ctx, id)

  assert out == other_video
}

pub fn video_delete_000_test() {
  use ctx <- with_db
  let yt = with_yt_actor()

  let out =
    { "/api/video/delete/" <> id.to_string(id) }
    |> simulate.browser_request(http.Get, _)
    |> web.on_request(ctx, _, yt)

  let expected = wisp.ok()

  assert out == expected
}

pub fn video_delete_001_test() {
  use ctx <- with_db
  let yt = with_yt_actor()

  let assert Ok(_) = db.video_upsert(ctx, video)

  let out =
    { "/api/video/delete/" <> id.to_string(id) }
    |> simulate.browser_request(http.Get, _)
    |> web.on_request(ctx, _, yt)

  let expected = wisp.ok()

  assert out == expected

  let assert Error(_) = db.video_fetch(ctx, id)
}

pub fn video_insert_000_test() {
  use ctx <- with_db
  let yt = with_yt_actor()

  let out =
    simulate.browser_request(http.Post, "/api/video/insert")
    |> simulate.json_body(video |> video.to_json)
    |> web.on_request(ctx, _, yt)

  let expected = wisp.ok()

  assert out == expected

  let assert Ok(out) = db.video_fetch(ctx, id)

  assert out == video
}

// TODO: test video_fetch -> we need youtube actor for this

pub fn video_fetch_all_000_test() {
  use ctx <- with_db
  let yt = with_yt_actor()

  let out =
    simulate.browser_request(http.Get, "/api/video/fetch-all")
    |> web.on_request(ctx, _, yt)

  let expected =
    wisp.ok()
    |> wisp.json_body([] |> json.array(video.to_json) |> json.to_string)

  assert out == expected
}

pub fn video_fetch_all_001_test() {
  use ctx <- with_db
  let yt = with_yt_actor()

  let assert Ok(_) = db.video_upsert(ctx, video)

  let out =
    simulate.browser_request(http.Get, "/api/video/fetch-all")
    |> web.on_request(ctx, _, yt)

  let expected =
    wisp.ok()
    |> wisp.json_body([video] |> json.array(video.to_json) |> json.to_string)

  assert out == expected
}
