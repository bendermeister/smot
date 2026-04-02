import backend/context
import backend/log
import backend/types.{type Logger, type YoutubeMsg, YoutubeFetchVideo}
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/hackney
import gleam/http
import gleam/http/request
import gleam/json
import gleam/otp/actor
import gleam/result
import gleam/uri
import middle/author
import middle/timestamp
import middle/video

pub type Builder {
  Builder(logger: Logger)
}

pub fn new() {
  Builder(logger: log.default_logger)
}

pub fn set_logger(_: Builder, logger: Logger) {
  Builder(logger:)
}

type State {
  State(logger: Logger)
}

fn build(builder: Builder) {
  State(logger: builder.logger)
}

pub fn start(builder: Builder) {
  builder
  |> build()
  |> actor.new()
  |> actor.on_message(on_message)
  |> actor.start()
}

fn on_message(state: State, msg: YoutubeMsg) {
  let YoutubeFetchVideo(reply_to:, id:) = msg

  let ctx = context.new("youtube", "", state.logger, process.new_subject())

  process.spawn(fn() {
    fetch_data(ctx, id)
    |> process.send(reply_to, _)
  })

  actor.continue(state)
}

fn fetch_data(ctx, id) {
  let video_url =
    id
    |> video.id_to_uri()
    |> uri.to_string()
    |> uri.percent_encode()

  let response =
    request.Request(..request.new(), host: "youtube.com")
    |> request.set_method(http.Get)
    |> request.set_path("/oembed")
    |> request.set_query([#("url", video_url)])
    |> hackney.send()
    |> log.info_on_error(ctx, "failed to fetch video data from youtube oembed")
    |> result.replace_error(Nil)
  use response <- result.try(response)

  response.body
  |> json.parse({
    use title <- decode.field("title", decode.string)
    use author_name <- decode.field("author_name", decode.string)
    use author_url <- decode.field("author_url", decode.string)
    use thumbnail <- decode.field("thumbnail_url", decode.string)
    let timestamp = timestamp.now()

    let author = author.Author(name: author_name, url: author_url)
    video.Video(id:, author:, title:, thumbnail:, timestamp:, tags: [])
    |> decode.success
  })
  |> log.info_on_error(ctx, "failed to parse response body from youtube oembed")
  |> result.replace_error(Nil)
}
