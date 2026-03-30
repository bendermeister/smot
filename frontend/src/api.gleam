import gleam/dynamic/decode
import gleam/result
import middle/id.{type Id}
import middle/video.{type Video}
import rsvp

pub fn video_fetch_all(to_message, error_message) {
  rsvp.expect_json(decode.list(video.json_decoder()), fn(videos) {
    videos
    |> result.map(to_message)
    |> result.unwrap(error_message("videos could not be loaded"))
  })
  |> rsvp.get("/api/video/fetch-all", _)
}

pub fn video_fetch(video: Id(Video), to_message, error_message) {
  rsvp.expect_json(video.json_decoder(), fn(video) {
    video
    |> result.map(to_message)
    |> result.unwrap(error_message("could not load video"))
  })
  |> rsvp.get("/api/video/fetch/" <> id.to_string(video), _)
}

pub fn video_insert(video, to_ok_message, to_error_message) {
  rsvp.expect_ok_response(fn(response) {
    response
    |> result.replace(to_ok_message("video saved"))
    |> result.unwrap(to_error_message("could not save video"))
  })
  |> rsvp.post("/api/video/insert", video.to_json(video), _)
}

pub fn video_delete(id, to_ok_message, to_error_message) {
  rsvp.expect_ok_response(fn(response) {
    case response {
      Ok(_) -> to_ok_message("video deleted")
      Error(_) -> to_error_message("video could not be deleted")
    }
  })
  |> rsvp.get("/api/video/delete/" <> id.to_string(id), _)
}

pub fn video_update(video, to_ok_message, to_error_message) {
  rsvp.expect_ok_response(fn(response) {
    case response {
      Ok(_) -> to_ok_message("video udpated")
      Error(_) -> to_error_message("video could not be updated")
    }
  })
  |> rsvp.post("/api/video/update", video.to_json(video), _)
}
