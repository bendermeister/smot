import gleam/json
import middle/author
import middle/video

pub fn to_from_json_test() {
  let video =
    video.Video(
      author: author.Author(name: "Some Name", url: "https://someauthor.com"),
      title: "This is a video",
      url: "https://videourl.com",
      thumbnail: "https://thumbnail.img",
      id: video.Id("someid"),
      timestamp: video.get_timestamp(),
    )

  let assert Ok(out) =
    video
    |> video.to_json
    |> json.to_string
    |> json.parse(video.json_decoder())

  assert out == video
}

pub fn to_from_json_id_test() {
  let id = video.Id(inner: "someid")

  let assert Ok(out) =
    id
    |> video.id_to_json()
    |> json.to_string()
    |> json.parse(video.id_decoder())

  assert out == id
}

pub fn id_from_uri_1_test() {
  let assert Ok(out) =
    video.id_from_url("https://youtu.be/dQw4w9WgXcQ?si=iBZ__-pk91I9Dt6s")
  assert out == video.Id("dQw4w9WgXcQ")

  let assert Ok(out) =
    video.id_from_url(
      "https://www.youtube.com/watch?v=KPtIx5ZFSOY&pp=ugUHEgVlbi1VUw%3D%3D",
    )
  assert out == video.Id("KPtIx5ZFSOY")

  let assert Ok(out) =
    "https://www.youtube.com/watch?v=BSgjU_Xu1Go"
    |> video.id_from_url()

  assert out == video.Id("BSgjU_Xu1Go")

  let assert Error(_) = video.id_from_url("this is not a url")
  let assert Error(_) = video.id_from_url("www.youtube.com")
}
