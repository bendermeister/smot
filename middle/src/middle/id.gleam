import gleam/dynamic/decode
import gleam/json
import gleam/string

pub type Id(a) {
  Id(String)
}

pub fn to_string(id: Id(a)) {
  let Id(id) = id
  id
}

pub fn from_string(id: String) {
  Id(id)
}

pub fn decoder() {
  decode.string |> decode.map(Id)
}

pub fn to_json(id) {
  id |> to_string |> json.string
}

pub fn compare(a: Id(a), b: Id(a)) {
  string.compare(to_string(a), to_string(b))
}
