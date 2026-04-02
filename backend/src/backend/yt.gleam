import backend/context
import backend/log
import backend/types.{type Logger, type YoutubeMsg, YoutubeFetchVideo}
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/hackney
import gleam/http
import gleam/http/request
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/otp/supervision
import gleam/result
import gleam/uri
import middle/author
import middle/id.{type Id}
import middle/timestamp
import middle/video.{type Video}

pub type Builder {
  Builder(logger: Logger, name: Option(process.Name(YoutubeMsg)))
}

pub fn new() {
  Builder(logger: log.default_logger, name: None)
}

pub fn set_logger(builder: Builder, logger: Logger) {
  Builder(..builder, logger:)
}

type State {
  State(logger: Logger)
}

fn build(builder: Builder) {
  State(logger: builder.logger)
}

pub fn named(builder: Builder, name) {
  Builder(..builder, name: Some(name))
}

pub fn supervised(builder: Builder) {
  fn() { start(builder) }
  |> supervision.worker()
}

pub fn start(builder: Builder) {
  let state = build(builder)

  let actor =
    actor.new(state)
    |> actor.on_message(on_message)

  let actor = case builder.name {
    Some(name) -> actor |> actor.named(name)
    None -> actor
  }

  actor
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

  let assert Ok(request) = request.to("https://youtube.com")

  // TODO: log youtube response better on error ... this is quite painful to debug
  let response =
    request
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

pub fn video_fetch(subject, id: Id(Video)) {
  actor.call(subject, 20_000, YoutubeFetchVideo(reply_to: _, id:))
}
