import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/uri.{type Uri}
import middle/author.{type Author}
import middle/id.{type Id}
import middle/timestamp.{type TimeStamp}

pub type Video {
  Video(
    id: Id(Video),
    author: Author,
    title: String,
    thumbnail: String,
    timestamp: TimeStamp,
  )
}

pub fn id_to_uri(id: Id(Video)) {
  uri.Uri(
    scheme: None,
    userinfo: None,
    host: Some("youtu.be"),
    port: None,
    path: id |> id.to_string(),
    query: None,
    fragment: None,
  )
}

pub fn id_from_uri(uri: Uri) {
  case uri.host {
    Some("www.youtube.com") | Some("youtube.com") ->
      uri.query
      |> option.to_result(Nil)
      |> result.try(uri.parse_query)
      |> result.try(list.key_find(_, "v"))
      |> result.map(id.from_string)
    Some("www.youtu.be") | Some("youtu.be") ->
      case uri.path_segments(uri.path) {
        [id] -> id |> id.from_string |> Ok
        _ -> Error(Nil)
      }
    Some(_) -> Error(Nil)
    None -> Error(Nil)
  }
}

pub fn to_json(video: Video) {
  [
    #("author", video.author |> author.to_json),
    #("title", video.title |> json.string),
    #("thumbnail", video.thumbnail |> json.string),
    #("id", video.id |> id.to_json()),
    #("timestamp", video.timestamp |> timestamp.to_json),
  ]
  |> json.object()
}

pub fn json_decoder() {
  use author <- decode.field("author", author.json_decoder())
  use title <- decode.field("title", decode.string)
  use thumbnail <- decode.field("thumbnail", decode.string)
  use timestamp <- decode.field("timestamp", timestamp.decoder())
  use id <- decode.field("id", id.decoder())

  Video(author:, title:, thumbnail:, id:, timestamp:)
  |> decode.success()
}
