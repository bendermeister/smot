import gleam/pair
import gleam/result
import lustre
import lustre/effect
import lustre/element
import modem
import pages/config
import pages/home
import pages/not_found
import route.{type Route}

type Page {
  Home(page: home.Model)
  Config(page: config.Model)
  NotFound(page: not_found.Model)
}

type Model {
  Model(page: Page)
}

type Msg {
  ClientLoadedUrl(route: Route)
  UpdateHome(msg: home.Msg)
  UpdateConfig(msg: config.Msg)
  UpdateNotFound(msg: not_found.Msg)
}

fn update(model: Model, msg: Msg) {
  case msg {
    ClientLoadedUrl(route:) -> {
      let #(page, effect) = case route {
        route.Home ->
          home.init()
          |> pair.map_first(Home)
          |> pair.map_second(effect.map(_, UpdateHome))

        route.Config ->
          config.init()
          |> pair.map_first(Config)
          |> pair.map_second(effect.map(_, UpdateConfig))

        route.NotFound(uri:) ->
          not_found.init(uri)
          |> pair.map_first(NotFound)
          |> pair.map_second(effect.map(_, UpdateNotFound))
      }
      let model = Model(page:)
      #(model, effect)
    }

    UpdateHome(msg:) ->
      case model.page {
        Home(page:) -> {
          let #(page, effect) = home.update(page, msg)
          let page = Home(page)
          let model = Model(page:)
          let effect = effect.map(effect, UpdateHome)
          #(model, effect)
        }

        _ -> #(model, effect.none())
      }

    UpdateConfig(msg:) ->
      case model.page {
        Config(page:) -> {
          let #(page, effect) = config.update(page, msg)
          let page = Config(page)
          let effect = effect.map(effect, UpdateConfig)
          #(Model(page:), effect)
        }

        _ -> #(model, effect.none())
      }

    UpdateNotFound(msg:) ->
      case model.page {
        NotFound(page:) -> {
          let #(page, effect) = not_found.update(page, msg)
          let page = NotFound(page)
          let effect = effect.map(effect, UpdateNotFound)
          #(Model(page:), effect)
        }

        _ -> #(model, effect.none())
      }
  }
}

fn view(model: Model) {
  case model.page {
    Home(page:) ->
      home.view(page)
      |> element.map(UpdateHome)

    Config(page:) ->
      config.view(page)
      |> element.map(UpdateConfig)

    NotFound(page:) ->
      not_found.view(page)
      |> element.map(UpdateNotFound)
  }
}

fn init(_) {
  let #(page, page_effect) =
    modem.initial_uri()
    |> result.map(route.from_uri)
    |> result.unwrap(route.Home)
    |> fn(route) {
      case route {
        route.Home ->
          home.init()
          |> pair.map_first(Home)
          |> pair.map_second(effect.map(_, UpdateHome))

        route.Config ->
          config.init()
          |> pair.map_first(Config)
          |> pair.map_second(effect.map(_, UpdateConfig))

        route.NotFound(uri:) ->
          not_found.init(uri)
          |> pair.map_first(NotFound)
          |> pair.map_second(effect.map(_, UpdateNotFound))
      }
    }

  let modem_effect =
    modem.init(fn(uri) {
      uri
      |> route.from_uri
      |> ClientLoadedUrl
    })

  let model = Model(page:)
  let effect =
    [page_effect, modem_effect]
    |> effect.batch()

  #(model, effect)
}

pub fn main() -> Nil {
  let assert Ok(_) =
    lustre.application(init, update, view)
    |> lustre.start("#app", Nil)

  Nil
}
