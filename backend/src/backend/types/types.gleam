import backend/context
import gleam/erlang/process.{type Subject}
import gleam/option.{type Option}
import middle/id.{type Id}
import middle/video

// *****************************************************************************
// reexports from middle
// *****************************************************************************
pub type Video =
  video.Video

// pub type VideoId =
//   video.Id

// *****************************************************************************
// Database Actor
// *****************************************************************************

pub type DatabaseMsg {
  DatabaseStop
  DatabaseVideoFetchAll(reply_to: Subject(Result(List(Video), Nil)))
  DatabaseVideoFetch(reply_to: Subject(Result(Video, Nil)), id: Id(Video))
  DatabaseInsert(reply_to: Subject(Result(Nil, Nil)), video: Video)
}

pub type Database =
  Subject(DatabaseMsg)

// *****************************************************************************
// Log Actor
// *****************************************************************************

pub type Log =
  Subject(LogMsg)

pub type LogLevel {
  LogInfo
  LogWarn
  LogError
}

pub type LogMsg {
  LogMsg(ctx: context.Context, level: LogLevel, message: String)
}

// *****************************************************************************
// Context
// *****************************************************************************

pub type Context {
  Context(
    id: Id(Context),
    parent: Option(Id(Context)),
    log: Log,
    database: Database,
  )
}
