import backend/db
import backend/log
import backend/server_config
import backend/types.{type Context}
import backend/yt
import gleam/erlang/process
import gleam/json
import gleam/option.{None}
import gleam/otp/static_supervisor
import gleam/result
import middle/id
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
  let yt_name = process.new_name("youtube-actor")

  let yt_actor =
    yt.new()
    |> yt.set_logger(ctx.logger)
    |> yt.named(yt_name)
    |> yt.supervised()

  let yt = process.named_subject(yt_name)

  let mist_actor =
    wisp_mist.handler(
      fn(req) { on_request(ctx, req, yt) },
      server_config.cookie_secret,
    )
    |> mist.new()
    |> mist.port(server_config.port)
    |> mist.bind(server_config.host)
    |> mist.supervised()

  static_supervisor.new(static_supervisor.OneForOne)
  |> static_supervisor.add(mist_actor)
  |> static_supervisor.add(yt_actor)
  |> static_supervisor.supervised()
}

// TODO: merge insert + update into a single upsert function to avoid confusion

pub fn on_request(ctx: Context, req: wisp.Request, yt) {
  use <- handle_api_error()
  case wisp.path_segments(req) {
    [] | ["index.html"] -> serve_file(ctx, "index.html", "text/html")
    ["frontend.js"] ->
      serve_file(ctx, "frontend.js", "text/javascript; charset=utf-8")
    ["frontend.css"] -> serve_file(ctx, "frontend.css", "text/css")
    ["api", "video", "fetch-all"] -> api_video_fetch_all(ctx)
    ["api", "video", "fetch", url] -> api_video_fetch(ctx, url, yt)
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

fn api_video_fetch(ctx: Context, id, yt) {
  log.info(ctx, "api: video fetch")

  let id = id |> id.from_string()

  let video =
    {
      let video = db.video_fetch(ctx, id)
      use <- result.lazy_or(video)

      log.info(ctx, "video is not in database - fetching from youtube")
      yt.video_fetch(yt, id)
      |> log.error_on_error(ctx, "could not fetch data from youtube")
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
