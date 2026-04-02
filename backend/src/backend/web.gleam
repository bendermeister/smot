import backend/db
import backend/log
import backend/server_config
import backend/types.{type Context}
import gleam/dynamic/decode
import gleam/hackney
import gleam/http/request
import gleam/json
import gleam/option.{None}
import gleam/result
import gleam/uri
import middle/author
import middle/id
import middle/timestamp
import middle/video
import mist
import wisp
import wisp/wisp_mist

type ApiError {
  BadDatabase
  BadRequest(String)
  BadYoutube
}

pub fn supervised(ctx: Context, server_config: server_config.ServerConfig) {
  wisp_mist.handler(
    fn(req) { on_request(ctx, req) },
    server_config.cookie_secret,
  )
  |> mist.new()
  |> mist.port(server_config.port)
  |> mist.bind(server_config.host)
  |> mist.supervised()
}

// TODO: merge insert + update into a single upsert function to avoid confusion

pub fn on_request(ctx: Context, req: wisp.Request) {
  use <- handle_api_error()
  case wisp.path_segments(req) {
    [] | ["index.html"] -> serve_file(ctx, "index.html", "text/html")
    ["frontend.js"] ->
      serve_file(ctx, "frontend.js", "text/javascript; charset=utf-8")
    ["frontend.css"] -> serve_file(ctx, "frontend.css", "text/css")
    ["api", "video", "fetch-all"] -> api_video_fetch_all(ctx)
    ["api", "video", "fetch", url] -> api_video_fetch(ctx, url)
    ["api", "video", "insert"] -> api_video_insert(ctx, req)
    ["api", "video", "delete", id] -> api_video_delete(ctx, id)
    ["api", "video", "update"] -> api_video_update(ctx, req)
    _ -> wisp.not_found() |> Ok
  }
}

// *****************************************************************************
// Middleware     
// *****************************************************************************

fn handle_api_error(
  handler: fn() -> Result(wisp.Response, ApiError),
) -> wisp.Response {
  case handler() {
    Ok(response) -> response
    Error(error) ->
      case error {
        BadDatabase ->
          wisp.internal_server_error()
          |> wisp.string_body("bad database")
        BadRequest(reason) -> wisp.bad_request(reason)
        BadYoutube ->
          wisp.internal_server_error()
          |> wisp.string_body("bad youtube")
      }
  }
}

// *****************************************************************************
// Api Endpoints  
// *****************************************************************************

fn api_video_update(ctx, req) {
  log.info(ctx, "api video update")

  let body =
    req
    |> wisp.read_body_bits()
    |> log.error_on_error(ctx, "could not read request body")
    |> result.replace_error(BadRequest("Invalid JSON"))
  use body <- result.try(body)

  let video =
    body
    |> json.parse_bits(video.json_decoder())
    |> log.error_on_error(ctx, "could not parse request body")
    |> result.replace_error(Nil)
    |> result.replace_error(BadRequest("Invalid JSON"))
  use video <- result.try(video)

  let result =
    db.video_upsert(ctx, video)
    |> log.error_on_error(ctx, "could not udpate video in database")
    |> result.replace_error(BadDatabase)
  use _ <- result.try(result)

  log.info(ctx, "successfully updated video in database")

  wisp.ok()
  |> Ok
}

fn api_video_delete(ctx, id) {
  log.info(ctx, "api video delete")
  let id = id.from_string(id)
  log.info(ctx, "with id: " <> id.to_string(id))

  let result =
    db.video_delete(ctx, id)
    |> log.error_on_error(ctx, "could not delete video")
    // error is probably bad request
    // todo: how to distinguish between bad database and bad request?
    |> result.replace_error(BadRequest("Invalid ID"))
  use _ <- result.try(result)

  wisp.ok()
  |> Ok
}

fn api_video_insert(ctx: Context, req) {
  log.info(ctx, "api: video insert")
  let body =
    wisp.read_body_bits(req)
    |> log.error_on_error(ctx, "could not read requst body")
    |> result.replace_error(BadRequest("Invalid JSON"))
  use body <- result.try(body)

  let video =
    body
    |> json.parse_bits(video.json_decoder())
    |> log.error_on_error(ctx, "could not parse request body")
    |> result.replace_error(Nil)
    |> result.replace_error(BadRequest("Invalid JSON"))
  use video <- result.try(video)

  let result =
    db.video_upsert(ctx, video)
    |> log.error_on_error(ctx, "could not insert video")
    |> result.replace_error(BadDatabase)
  use _ <- result.try(result)

  wisp.ok()
  |> Ok
}

fn api_video_fetch(ctx: Context, id) {
  log.info(ctx, "api: video fetch")

  let id = id |> id.from_string()

  let video =
    {
      let video = db.video_fetch(ctx, id)
      use <- result.lazy_or(video)

      log.info(ctx, "video is not in database fetching data")

      let video_url = id |> video.id_to_uri |> uri.to_string()

      // this should never fail as we pass static string url
      let assert Ok(request) = request.to("https://www.youtube.com/oembed/")

      // TODO: maybe format the hackey error correctly and log it
      let response =
        request
        |> request.set_query([#("url", video_url)])
        |> hackney.send()
        |> log.info_on_ok(ctx, "got response from youtube oembed")
        |> log.error_on_error(
          ctx,
          "could not fetch video data from youtube oembed",
        )
        |> result.replace_error(Nil)
      use response <- result.try(response)

      let decoder = {
        use title <- decode.field("title", decode.string)
        use author_name <- decode.field("author_name", decode.string)
        use author_url <- decode.field("author_url", decode.string)
        use thumbnail <- decode.field("thumbnail_url", decode.string)
        let timestamp = timestamp.now()

        let author = author.Author(name: author_name, url: author_url)
        video.Video(id:, author:, title:, thumbnail:, timestamp:, tags: [])
        |> decode.success
      }

      let video =
        response.body
        |> json.parse(decoder)
        |> log.error_on_error(ctx, "could not parse response body")
        |> result.replace_error(Nil)
      use video <- result.try(video)

      log.info(ctx, "got valid video from youtube")

      video |> Ok
    }
    // TODO: how to distiguish between bad youtube and bad request?
    |> result.replace_error(BadYoutube)
  use video <- result.try(video)

  video
  |> video.to_json
  |> json.to_string
  |> wisp.json_response(200)
  |> Ok
}

fn api_video_fetch_all(ctx) {
  log.info(ctx, "api: video fetch all")
  let videos =
    db.video_fetch_all(ctx)
    |> result.replace_error(BadDatabase)
  use videos <- result.try(videos)

  videos
  |> json.array(video.to_json)
  |> json.to_string()
  |> wisp.json_response(200)
  |> Ok
}

// *****************************************************************************
// Helper Functions
// *****************************************************************************

fn serve_file(ctx: Context, name: String, content_type: String) {
  wisp.ok()
  |> wisp.set_body(wisp.File(ctx.static_content <> "/" <> name, 0, None))
  |> wisp.set_header("content-type", content_type)
  |> Ok
}
