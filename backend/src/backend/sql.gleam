import backend/log
import gleam/dynamic/decode
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import sqlight

pub fn close(ctx, conn) {
  sqlight.close(conn)
  |> log.error_on_errorf(ctx, error_format)
  |> result.replace_error(Nil)
}

pub fn open(ctx, path: String) {
  sqlight.open(path)
  |> log.error_on_errorf(ctx, error_format)
  |> log.error_on_error(ctx, "sql: could not open database")
  |> result.replace_error(Nil)
}

pub opaque type Query(a) {
  Query(
    sql: String,
    parameter: List(sqlight.Value),
    returning: decode.Decoder(a),
  )
}

pub fn query(sql: String) {
  Query(sql:, parameter: [], returning: decode.success(Nil))
}

pub fn parameter(query: Query(a), value: sqlight.Value) {
  Query(..query, parameter: [value, ..query.parameter])
}

pub fn returning(query: Query(Nil), decoder: decode.Decoder(b)) {
  Query(..query, returning: decoder)
}

pub fn text(text: String) {
  sqlight.text(text)
}

pub fn int(int: Int) {
  sqlight.int(int)
}

pub fn float(float: Float) {
  sqlight.float(float)
}

pub fn bool(value: Bool) {
  sqlight.bool(value)
}

pub fn null() {
  sqlight.null()
}

pub fn nullable(value: option.Option(a), map: fn(a) -> sqlight.Value) {
  sqlight.nullable(map, value)
}

fn error_format(error: sqlight.Error) {
  let sqlight.SqlightError(code:, message:, offset:) = error
  let code = sqlight.error_code_to_int(code) |> int.to_string()
  let offset = offset |> int.to_string()
  "sql: " <> code <> " " <> message <> " at offset: " <> offset
}

pub fn fetch(
  query: Query(a),
  ctx,
  connection: sqlight.Connection,
) -> Result(List(a), Nil) {
  sqlight.query(
    query.sql,
    connection,
    query.parameter |> list.reverse,
    query.returning,
  )
  |> log.error_on_errorf(ctx, error_format)
  |> result.replace_error(Nil)
}

pub fn fetch_one(query: Query(a), ctx, connection: sqlight.Connection) {
  case fetch(query, ctx, connection) {
    Ok([]) -> {
      log.error(ctx, "sql: expected one got none")
      Error(Nil)
    }
    Ok([value]) -> Ok(value)
    Ok(_) -> {
      log.error(ctx, "sql: expected one got many")
      Error(Nil)
    }
    Error(Nil) -> Error(Nil)
  }
}

pub fn execute(query: Query(a), ctx, connection: sqlight.Connection) {
  case fetch(query, ctx, connection) {
    Ok([]) -> Ok(Nil)
    Ok(_) -> {
      log.error(ctx, "sql: expected none got at least one")
      Error(Nil)
    }
    Error(Nil) -> Error(Nil)
  }
}

pub fn decode_bool() {
  sqlight.decode_bool()
}
