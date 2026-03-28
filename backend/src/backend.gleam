import backend/context
import backend/db_actor
import backend/migration
import backend/server_config
import backend/web
import dot_env
import gleam/erlang/process
import gleam/otp/static_supervisor
import sqlight

pub fn main() -> Nil {
  // setup dotenv
  dot_env.new()
  |> dot_env.set_path(".env")
  |> dot_env.load()

  // read server config from environment
  let server_config = server_config.read_from_environment()

  // run database migrations
  let assert Ok(_) =
    sqlight.with_connection(server_config.db_path, migration.migrate)

  // create db_actor
  let db_name = process.new_name("db")
  let db_actor = db_actor.supervised(db_name, server_config.db_path)

  // create initial context
  let db = process.named_subject(db_name)
  let ctx = context.Context(db:)

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
