import backend/db_actor
import gleam/erlang/process

pub type Context {
  Context(db: process.Subject(db_actor.Msg))
}
