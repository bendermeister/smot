import backend/context
import backend/db
import backend/log
import backend/server_config
import gleam/dynamic/decode
import gleam/hackney
import gleam/http/request
import gleam/json
import gleam/result
import middle/author
import middle/video
import mist
import wisp
import wisp/wisp_mist

pub fn supervised(
  ctx: context.Context,
  server_config: server_config.ServerConfig,
) {
  wisp_mist.handler(
    fn(req) { on_request(ctx, req) },
    server_config.cookie_secret,
  )
  |> mist.new()
  |> mist.port(server_config.port)
  |> mist.bind(server_config.host)
  |> mist.supervised()
}

pub fn on_request(ctx: context.Context, req: wisp.Request) {
  case wisp.path_segments(req) {
    ["api", "video", "fetch-all"] -> api_video_fetch_all(ctx)
    ["api", "video", "fetch", url] -> api_video_fetch(ctx, url)
    ["api", "video", "insert"] -> api_video_insert(ctx, req)
    _ -> wisp.not_found() |> Ok
  }
  |> result.unwrap(wisp.internal_server_error())
}

fn api_video_insert(ctx, req) {
  log.info("api: video insert")
  let body =
    wisp.read_body_bits(req)
    |> log.on_error("could not read requst body")
  use body <- result.try(body)

  let video =
    body
    |> json.parse_bits(video.json_decoder())
    |> log.on_error("could not parse request body")
    |> result.replace_error(Nil)
  use video <- result.try(video)

  let result =
    db.video_insert(ctx, video)
    |> log.on_error("could not insert video")
  use _ <- result.try(result)

  wisp.ok()
  |> Ok
}

fn api_video_fetch(ctx, id) {
  log.info("api: video fetch")

  let id = id |> video.id_from_string()

  let video = {
    let video = db.video_fetch(ctx, id)
    use <- result.lazy_or(video)

    log.info("video is not in database fetching data")

    let video_url = id |> video.id_to_url()

    // this should never fail as we pass static string url
    let assert Ok(request) = request.to("https://www.youtube.com/oembed/")

    // TODO: maybe format the hackey error correctly and log it
    let response =
      request
      |> request.set_query([#("url", video_url)])
      |> hackney.send()
      |> log.on_ok("got response from youtube oembed")
      |> log.on_error("could not fetch video data from youtube oembed")
      |> result.replace_error(Nil)
    use response <- result.try(response)

    let decoder = {
      use title <- decode.field("title", decode.string)
      use author_name <- decode.field("author_name", decode.string)
      use author_url <- decode.field("author_url", decode.string)
      use thumbnail <- decode.field("thumbnail_url", decode.string)

      let author = author.Author(name: author_name, url: author_url)
      video.Video(id:, author:, title:, url: video_url, thumbnail:)
      |> decode.success
    }

    let video =
      response.body
      |> json.parse(decoder)
      |> log.on_error("could not parse response body")
      |> result.replace_error(Nil)
    use video <- result.try(video)

    log.info("got valid video from youtube")

    video |> Ok
  }
  use video <- result.try(video)

  video
  |> video.to_json
  |> json.to_string
  |> wisp.json_response(200)
  |> Ok
}

fn api_video_fetch_all(ctx) {
  log.info("api: video fetch all")
  let videos = db.video_fetch_all(ctx)
  use videos <- result.try(videos)

  videos
  |> json.array(video.to_json)
  |> json.to_string()
  |> wisp.json_response(200)
  |> Ok
}
