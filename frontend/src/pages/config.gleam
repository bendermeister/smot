import lustre/effect
import lustre/element/html

pub type Model {
  Model
}

pub type Msg

pub fn init() {
  #(Model, effect.none())
}

pub fn update(model: Model, msg: Msg) {
  todo
}

pub fn view(model: Model) {
  html.text("config page")
}
