import component
import gleam/dynamic/decode
import gleam/int
import gleam/io
import gleam/list
import gleam/order
import gleam/pair
import gleam/result
import lustre
import lustre/attribute.{class} as attr
import lustre/effect
import lustre/element/html.{button, div, h1, input, span, text}
import lustre/event.{on_change, on_click, on_input}
import middle/video
import rsvp

type Model {
  Model(query: String, videos: List(video.Video))
}

type Msg {
  UserInputQuery(query: String)
  UserPressedAdd
  GotMessageError(msg: String)
  GotMessage(msg: String)
  ClientGotVideo(video: video.Video)
  ClientGotVideos(videos: List(video.Video))
  NoOp
}

fn update(model: Model, msg: Msg) {
  let handle_error = fn(msg: String) {
    io.println_error(msg)
    #(model, effect.none())
  }

  case msg {
    UserInputQuery(query:) -> Model(..model, query:) |> pair.new(effect.none())
    UserPressedAdd -> {
      video.id_from_url(model.query)
      |> echo
      |> result.map(fn(id) {
        // TODO: we need video.id_to_string 
        let url = "/api/video/fetch/" <> id.inner

        let handler =
          rsvp.expect_json(video.json_decoder(), fn(result) {
            result
            |> result.map(ClientGotVideo)
            |> result.unwrap(GotMessageError("could not fetch video"))
          })

        let effect = rsvp.get(url, handler)
        let model = Model(..model, query: "")
        #(model, effect)
      })
      |> result.lazy_unwrap(fn() {
        handle_error("'" <> model.query <> "' is not a valid youtube url")
      })
    }
    GotMessageError(msg:) -> handle_error(msg)
    GotMessage(msg:) -> {
      io.println(msg)
      #(model, effect.none())
    }
    ClientGotVideo(video:) -> {
      let url = "/api/video/insert"
      let handler =
        rsvp.expect_ok_response(fn(result) {
          result
          |> result.replace(NoOp)
          |> result.unwrap(GotMessageError("could not insert video"))
        })
      let effect = rsvp.post(url, video.to_json(video), handler)
      let model = Model(..model, videos: [video, ..model.videos])
      #(model, effect)
    }
    NoOp -> #(model, effect.none())
    ClientGotVideos(videos:) -> {
      let videos =
        videos
        |> list.sort(fn(a, b) {
          int.compare(a.timestamp.inner, b.timestamp.inner)
          |> order.negate()
        })

      let model = Model(..model, videos:)

      #(model, effect.none())
    }
  }
}

fn view_controls(query: String) {
  div([class("w-full h-[3rem] flex flex-row gap-4")], [
    input([
      on_input(UserInputQuery),
      class("h-full flex-grow outline-none shadow rounded p-2"),
      attr.placeholder("search..."),
      attr.value(query),
    ]),
    button(
      [
        on_click(UserPressedAdd),
        class("h-full px-8 p-2 text-center"),
        class("shadow rounded text-violet-400 font-bold"),
        class("transition-colors ease-in-out duration-250"),
        class("hover:cursor-pointer hover:bg-violet-100"),
      ],
      [text("add")],
    ),
  ])
}

fn view_videos(videos: List(video.Video)) {
  div(
    [
      class("w-full h-full"),
      class("overflow-y-scroll no-scrollbar"),
      class("grid grid-cols-[repeat(auto-fit,384px)] gap-4 justify-center"),
    ],
    videos
      |> list.map(fn(video) { component.video([component.video_data(video)]) }),
  )
}

fn view(model: Model) {
  div(
    [
      class("w-screen h-screen relative p-4 flex flex-col gap-4"),
    ],
    [view_controls(model.query), view_videos(model.videos)],
  )
}

fn init(_) {
  let effect =
    fn(result) {
      result
      |> result.map(ClientGotVideos)
      |> result.unwrap(GotMessageError("could not fetch playlist"))
    }
    |> rsvp.expect_json(decode.list(video.json_decoder()), _)
    |> rsvp.get("/api/video/fetch-all", _)

  let model = Model(query: "", videos: [])
  #(model, effect)
}

pub fn main() {
  let assert Ok(_) = component.register()
  let assert Ok(_) =
    lustre.application(init:, update:, view:)
    |> lustre.start("#app", Nil)

  Nil
}
