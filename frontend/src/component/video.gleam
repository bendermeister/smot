import gleam/dynamic/decode
import gleam/option
import gleam/pair
import gleam/uri
import lustre
import lustre/attribute.{class, href, src}
import lustre/component
import lustre/effect
import lustre/element
import lustre/element/html.{a, div, img, text}
import middle/video

type Model {
  Model(video: option.Option(video.Video))
}

type Msg {
  GotVideo(video: video.Video)
}

fn update(_: Model, msg: Msg) {
  case msg {
    GotVideo(video:) ->
      video
      |> option.Some
      |> Model(video: _)
      |> pair.new(effect.none())
  }
}

fn init(_) {
  #(Model(video: option.None), effect.none())
}

fn view(model: Model) {
  model.video
  |> option.map(view_video)
  |> option.unwrap(element.none())
}

fn view_video(video: video.Video) {
  div(
    [
      class("flex flex-col gap-2"),
      class("duration-250 transition-all ease-in-out"),
      class("hover:opacity-[0.8] duration-250 hover:transform-[scale(102%)]"),
    ],
    [
      a(
        [
          class(
            "w-[384px] h-[216px] overflow-hidden hover:cursor-pointer rounded-t",
          ),
          href(video.id_to_uri(video.id) |> uri.to_string),
        ],
        [
          img([src(video.thumbnail), class("w-full h-full object-cover")]),
        ],
      ),
      div([class("flex flex-col")], [
        div([class("text-ellipsis line-clamp-1")], [
          text(video.title),
        ]),
        a(
          [
            href(video.author.url),
            class("hover:cursor-pointer"),
            class("text-ellipsis line-clamp-1 text-sm text-gray-500"),
          ],
          [
            text(video.author.name),
          ],
        ),
      ]),
    ],
  )
}

pub fn register() {
  lustre.component(init, update, view, [
    component.on_property_change(
      "video",
      video.json_decoder() |> decode.map(GotVideo),
    ),
  ])
  |> lustre.register("x-smot-video")
}

pub fn element(attributes) {
  element.element("x-smot-video", attributes, [])
}

pub fn property(video: video.Video) {
  attribute.property("video", video.to_json(video))
}
