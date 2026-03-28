import gleam/json
import middle/bucket

pub fn to_from_json_test() {
  let bucket = bucket.from_string("some-bucket")

  let assert Ok(out) =
    bucket
    |> bucket.to_json()
    |> json.to_string()
    |> json.parse(bucket.decoder())

  assert out == bucket
}

pub fn to_from_string_test() {
  let bucket = bucket.from_string("some-other-bucket")

  let out =
    bucket
    |> bucket.to_string()
    |> bucket.from_string()

  assert out == bucket
}
