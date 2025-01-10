import gleam/result

import dot_env
import dot_env/env
import pog

pub type Settings {
  Settings(secret_key: String, db_uri: String, port: Int)
}

/// Read the DATABASE_URL environment variable.
/// Generate the pog.Config from that database URL.
/// Finally, connect to database.
pub fn read_connection_uri(db_url: String) -> Result(pog.Connection, Nil) {
  let assert Ok(config) =
    pog.url_config(db_url) |> result.map(pog.pool_size(_, 15))
  Ok(pog.connect(config))
}

pub fn get_settings(env_path: String) -> Result(Settings, Nil) {
  dot_env.new()
  |> dot_env.set_path(env_path)
  |> dot_env.set_debug(False)
  |> dot_env.load

  let app_secret = env.get_string_or("APP_SECRET_KEY", "test_secret")
  let port = env.get_int_or("APP_PORT", 8000)
  let assert Ok(db_uri) = env.get_string("DATABASE_URL")
  Ok(Settings(secret_key: app_secret, db_uri: db_uri, port: port))
}
