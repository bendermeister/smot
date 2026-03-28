import birl
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import gleam/uri
import middle/author.{type Author}

pub type Id {
  Id(inner: String)
}

pub type TimeStamp {
  TimeStamp(inner: Int)
}

pub fn get_timestamp() {
  birl.now() |> birl.to_unix |> TimeStamp
}

pub type Video {
  Video(
    id: Id,
    author: Author,
    title: String,
    url: String,
    thumbnail: String,
    timestamp: TimeStamp,
  )
}

pub fn id_from_string(id: String) {
  Id(id)
}

pub fn timestamp_decoder() {
  decode.int |> decode.map(TimeStamp)
}

pub fn id_to_url(id: Id) {
  "https://youtu.be/" <> id.inner
}

pub fn id_from_url(url: String) {
  let url = url |> string.trim()
  let uri = uri.parse(url)
  use uri <- result.try(uri)

  case uri.host {
    Some("youtube.com") | Some("www.youtube.com") -> {
      uri.query
      |> option.to_result(Nil)
      |> result.try(uri.parse_query)
      |> result.try(list.key_find(_, "v"))
      |> result.map(Id)
    }
    Some("youtu.be") ->
      case uri.path_segments(uri.path) {
        [id] -> Id(inner: id) |> Ok
        _ -> Error(Nil)
      }
    Some(_) -> Error(Nil)
    None -> Error(Nil)
  }
}

pub fn id_to_json(id: Id) {
  id.inner |> json.string
}

pub fn id_decoder() {
  decode.string
  |> decode.then(fn(inner) { Id(inner:) |> decode.success() })
}

pub fn to_json(video: Video) {
  [
    #("author", video.author |> author.to_json),
    #("title", video.title |> json.string),
    #("url", video.url |> json.string),
    #("thumbnail", video.thumbnail |> json.string),
    #("id", video.id |> id_to_json()),
    #("timestamp", video.timestamp.inner |> json.int),
  ]
  |> json.object()
}

pub fn json_decoder() {
  use author <- decode.field("author", author.json_decoder())
  use title <- decode.field("title", decode.string)
  use url <- decode.field("url", decode.string)
  use thumbnail <- decode.field("thumbnail", decode.string)
  use timestamp <- decode.field("timestamp", timestamp_decoder())
  use id <- decode.field("id", id_decoder())
  Video(author:, title:, url:, thumbnail:, id:, timestamp:)
  |> decode.success()
}
