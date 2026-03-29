import gleam/erlang/process.{type Subject}
import gleam/json
import gleam/option.{type Option}
import middle/id.{type Id}
import middle/video

// *****************************************************************************
// reexports from middle
// *****************************************************************************
pub type Video =
  video.Video

// *****************************************************************************
// Database Actor
// *****************************************************************************

pub type DatabaseMsg {
  DatabaseStop
  DatabaseVideoFetchAll(reply_to: Subject(Result(List(Video), Nil)))
  DatabaseVideoFetch(reply_to: Subject(Result(Video, Nil)), id: Id(Video))
  DatabaseVideoInsert(reply_to: Subject(Result(Nil, Nil)), video: Video)
}

pub type Database =
  Subject(DatabaseMsg)

// *****************************************************************************
// Log Actor
// *****************************************************************************

pub type Logger =
  fn(json.Json) -> Nil

pub type LogLevel {
  LogInfo
  LogWarn
  LogError
}

// *****************************************************************************
// Context
// *****************************************************************************

pub type Context {
  Context(
    id: Id(Context),
    parent: Option(Id(Context)),
    logger: Logger,
    database: Database,
    static_content: String,
  )
}
