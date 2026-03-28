import birl
import gleam/dynamic/decode
import gleam/int
import gleam/json

pub type TimeStamp {
  TimeStamp(Int)
}

pub fn now() {
  birl.now() |> birl.to_unix() |> TimeStamp
}

pub fn to_int(t: TimeStamp) {
  let TimeStamp(t) = t
  t
}

pub fn to_string(t: TimeStamp) {
  t |> to_int |> int.to_string
}

pub fn to_json(t: TimeStamp) {
  t |> to_int |> json.int
}

pub fn from_int(int: Int) {
  int |> TimeStamp
}

pub fn decoder() {
  decode.int |> decode.map(TimeStamp)
}

pub fn compare(a, b) {
  int.compare(to_int(a), to_int(b))
}
