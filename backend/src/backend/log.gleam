import backend/types.{type Context, type LogLevel, LogError, LogInfo, LogWarn}
import gleam/io
import gleam/json
import gleam/result
import middle/id

fn level_to_string(level: LogLevel) {
  case level {
    LogInfo -> "info"
    LogWarn -> "warn"
    LogError -> "error"
  }
}

pub fn default_logger(value) {
  value
  |> json.to_string
  |> io.println
}

fn log(ctx: Context, level: LogLevel, message: String) {
  [
    #("self", ctx.id |> id.to_json),
    #("parent", ctx.parent |> json.nullable(id.to_json)),
    #("level", level |> level_to_string |> json.string),
    #("message", message |> json.string),
  ]
  |> json.object()
  |> ctx.logger()
}

fn on_ok(result, ctx, level, message) {
  result
  |> result.map(fn(ok) {
    log(ctx, level, message)
    ok
  })
}

fn on_error(result, ctx, level, message) {
  result
  |> result.map_error(fn(err) {
    log(ctx, level, message)
    err
  })
}

fn on_errorf(result, ctx, level, to_msg) {
  result
  |> result.map_error(fn(err) {
    log(ctx, level, to_msg(err))
    err
  })
}

pub fn info(ctx, msg) {
  log(ctx, LogInfo, msg)
}

pub fn warn(ctx, msg) {
  log(ctx, LogWarn, msg)
}

pub fn error(ctx, msg) {
  log(ctx, LogError, msg)
}

pub fn info_on_error(result, ctx, message) {
  on_error(result, ctx, LogInfo, message)
}

pub fn warn_on_error(result, ctx, message) {
  on_error(result, ctx, LogWarn, message)
}

pub fn error_on_error(result, ctx, message) {
  on_error(result, ctx, LogError, message)
}

pub fn info_on_ok(result, ctx, message) {
  on_ok(result, ctx, LogInfo, message)
}

pub fn warn_on_ok(result, ctx, message) {
  on_ok(result, ctx, LogWarn, message)
}

pub fn error_on_ok(result, ctx, message) {
  on_ok(result, ctx, LogError, message)
}

pub fn info_on_errorf(result, ctx, to_msg) {
  on_errorf(result, ctx, LogInfo, to_msg)
}

pub fn warn_on_errorf(result, ctx, to_msg) {
  on_errorf(result, ctx, LogWarn, to_msg)
}

pub fn error_on_errorf(result, ctx, to_msg) {
  on_errorf(result, ctx, LogError, to_msg)
}
