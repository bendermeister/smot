import gleam/dynamic/decode
import gleam/json

pub type Author {
  Author(name: String, url: String)
}

pub fn to_json(author: Author) {
  [#("name", author.name |> json.string), #("url", author.url |> json.string)]
  |> json.object
}

pub fn json_decoder() {
  use name <- decode.field("name", decode.string)
  use url <- decode.field("url", decode.string)

  Author(name:, url:)
  |> decode.success
}
