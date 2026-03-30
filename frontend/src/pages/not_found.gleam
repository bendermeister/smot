import gleam/uri.{type Uri}
import layout/base.{layout}
import lustre/attribute.{class}
import lustre/effect
import lustre/element/html.{div, h1, p, text}

pub type Model {
  Model(uri: Uri)
}

pub type Msg

pub fn init(uri) {
  #(Model(uri:), effect.none())
}

pub fn update(model: Model, _: Msg) {
  #(model, effect.none())
}

pub fn view(model: Model) {
  div([class("not-found-main")], [
    h1([], [text("/404")]),
    p([], [
      text("the route: " <> model.uri |> uri.to_string() <> " is not available"),
    ]),
  ])
  |> layout()
}
