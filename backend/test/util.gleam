import backend/context
import backend/db
import backend/log
import backend/types.{DatabaseStop}
import gleam/otp/actor

pub fn with_db_logger(handler) {
  let logger = log.default_logger

  let assert Ok(db) =
    db.new()
    |> db.path(":memory:")
    |> db.logger(logger)
    |> db.start()

  let ctx = context.new("test", "", logger, db.data)

  let _ = handler(ctx)

  actor.send(db.data, DatabaseStop)
}

pub fn with_db(handler) {
  // let logger = log.default_logger
  let logger = fn(_) { Nil }

  let assert Ok(db) =
    db.new()
    |> db.path(":memory:")
    |> db.logger(logger)
    |> db.start()

  let ctx = context.new("test", "", logger, db.data)

  let _ = handler(ctx)

  actor.send(db.data, DatabaseStop)
}
