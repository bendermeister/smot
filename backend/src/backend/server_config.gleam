import dot_env/env

pub type ServerConfig {
  ServerConfig(db_path: String, port: Int, host: String, cookie_secret: String)
}

pub fn read_from_environment() {
  let assert Ok(db_path) = env.get_string("SMOT_SQLITE_PATH")
  let assert Ok(port) = env.get_int("SMOT_PORT")
  let assert Ok(host) = env.get_string("SMOT_HOST")
  let assert Ok(cookie_secret) = env.get_string("SMOT_COOKIE_SECRET")

  ServerConfig(db_path:, port:, host:, cookie_secret:)
}
