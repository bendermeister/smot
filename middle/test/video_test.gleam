import gleam/json
import gleam/result
import gleam/uri
import middle/author
import middle/id.{Id}
import middle/timestamp
import middle/video

pub fn to_from_json_test() {
  let video =
    video.Video(
      author: author.Author(name: "Some Name", url: "https://someauthor.com"),
      title: "This is a video",
      thumbnail: "https://thumbnail.img",
      id: Id("someid"),
      timestamp: timestamp.now(),
      tags: ["hello", "world"],
    )

  let assert Ok(out) =
    video
    |> video.to_json
    |> json.to_string
    |> json.parse(video.json_decoder())

  assert out == video
}

pub fn id_from_uri_1_test() {
  let assert Ok(out) =
    "https://youtu.be/dQw4w9WgXcQ?si=iBZ__-pk91I9Dt6s"
    |> uri.parse()
    |> result.try(video.id_from_uri)
  assert out == Id("dQw4w9WgXcQ")

  let assert Ok(out) =
    "https://www.youtube.com/watch?v=KPtIx5ZFSOY&pp=ugUHEgVlbi1VUw%3D%3D"
    |> uri.parse
    |> result.try(video.id_from_uri)
  assert out == Id("KPtIx5ZFSOY")

  let assert Ok(out) =
    "https://www.youtube.com/watch?v=BSgjU_Xu1Go"
    |> uri.parse()
    |> result.try(video.id_from_uri)

  assert out == Id("BSgjU_Xu1Go")

  let assert Error(_) =
    "www.youtube.com"
    |> uri.parse()
    |> result.try(video.id_from_uri)
}
