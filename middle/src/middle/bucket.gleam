import gleam/dynamic/decode
import gleam/json
import gleam/string

pub opaque type Bucket {
  Bucket(id: String)
}

pub fn to_json(bucket: Bucket) {
  bucket.id |> json.string()
}

pub fn decoder() {
  decode.string
  |> decode.then(fn(id) {
    Bucket(id:)
    |> decode.success()
  })
}

pub fn to_string(bucket: Bucket) {
  bucket.id
}

pub fn from_string(id: String) {
  id
  |> string.lowercase()
  |> string.trim()
  |> Bucket(id: _)
}
