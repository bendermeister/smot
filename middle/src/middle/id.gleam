import gleam/dynamic/decode

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
