import backend/types.{type Context, Context}
import gleam/option.{None, Some}
import middle/id
import youid/uuid

/// create new root context
pub fn new(name, logger, database) {
  let id = name |> id.from_string()
  Context(id:, parent: None, logger:, database:)
}

/// create new child context associated with given parent
pub fn child(ctx: Context) {
  let id = uuid.v4() |> uuid.to_string |> id.from_string()
  Context(..ctx, parent: Some(ctx.id), id:)
}
