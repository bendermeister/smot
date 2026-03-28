import backend/context
import backend/db
import backend/log
import backend/server_config
import backend/web
import dot_env
import gleam/erlang/process
import gleam/otp/static_supervisor

pub fn main() -> Nil {
  // setup dotenv
  dot_env.new()
  |> dot_env.set_path(".env")
  |> dot_env.load()

  // actor names 
  let db_name = process.new_name("database")

  // read server config from environment
  let server_config = server_config.read_from_environment()

  let db_subject = process.named_subject(db_name)

  let logger = log.default_logger

  let db_actor =
    db.new()
    |> db.named(db_name)
    |> db.logger(logger)
    |> db.path(server_config.db_path)
    |> db.supervised()

  let ctx = context.new("http", logger, db_subject)

  // create web actor
  let web_actor = web.supervised(ctx, server_config)

  // build supervisor tree with web actor and db actor
  let assert Ok(_) =
    static_supervisor.new(static_supervisor.OneForOne)
    |> static_supervisor.add(db_actor)
    |> static_supervisor.add(web_actor)
    |> static_supervisor.start()

  process.sleep_forever()
}
