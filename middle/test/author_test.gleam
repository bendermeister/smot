import gleam/json
import middle/author

pub fn to_from_json_test() {
  let author =
    author.Author(name: "This is some name", url: "https://thisissomeurl.com")

  let assert Ok(out) =
    author
    |> author.to_json()
    |> json.to_string()
    |> json.parse(author.json_decoder())

  assert out == author
}
