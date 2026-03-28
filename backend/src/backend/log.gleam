import gleam/io
import gleam/result

fn log(level: String, message: String) {
  io.println("[" <> level <> "]: " <> message)
}

pub fn info(message) {
  log("info", message)
}

pub fn error(message) {
  log("error", message)
}

pub fn on_error(result: Result(a, b), message) {
  result
  |> result.map_error(fn(err) {
    error(message)
    err
  })
}

pub fn on_errorf(result: Result(a, b), to_message) {
  result
  |> result.map_error(fn(err) {
    error(to_message(err))
    err
  })
}

pub fn on_ok(result: Result(a, b), message) {
  result
  |> result.map(fn(x) {
    info(message)
    x
  })
}
