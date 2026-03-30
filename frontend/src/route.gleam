import gleam/uri.{type Uri}

pub type Route {
  Home
  Config
  NotFound(uri: Uri)
}

pub fn from_uri(uri: Uri) {
  case uri.path_segments(uri.path) {
    [] -> Home
    ["config"] -> Config
    _ -> NotFound(uri)
  }
}
