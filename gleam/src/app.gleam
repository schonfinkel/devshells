import app/router
import app/web.{Context}

import gleam/erlang/process
import gleam/option.{Some}

import dot_env
import dot_env/env
import mist
import pog
import wisp
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()

  dot_env.new()
  |> dot_env.set_path(".env")
  |> dot_env.set_debug(False)
  |> dot_env.load()

  let port = 8000

  let assert Ok(secret_key) = env.get_string("APP_SECRET_KEY")
  let assert Ok(pg_host) = env.get_string("PG_HOSTNAME")
  let assert Ok(pg_database) = env.get_string("PG_DATABASE")
  let assert Ok(pg_user) = env.get_string("PG_USER")
  let assert Ok(pg_password) = env.get_string("PG_PASSWORD")

  // Start a database connection pool.
  // Typically you will want to create one pool for use in your program
  let _db =
    pog.default_config()
    |> pog.host(pg_host)
    |> pog.database(pg_database)
    |> pog.user(pg_user)
    |> pog.password(Some(pg_password))
    |> pog.pool_size(15)
    |> pog.connect

  let ctx = Context(static_directory: static_dir())

  let handler = router.handle_request(_, ctx)

  let assert Ok(_) =
    wisp_mist.handler(handler, secret_key)
    |> mist.new
    |> mist.port(port)
    |> mist.start_http

  process.sleep_forever()
}

pub fn static_dir() {
  let assert Ok(priv_directory) = wisp.priv_directory("app")
  priv_directory <> "static"
}
