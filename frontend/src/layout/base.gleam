import lustre/attribute.{class}
import lustre/element/html.{div}

pub fn layout(child) {
  div([class("w-screen h-screen p-8")], [child])
}
