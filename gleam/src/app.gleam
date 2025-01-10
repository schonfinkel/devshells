import app/router
import app/settings.{get_settings, read_connection_uri}
import app/web.{Context}

import gleam/erlang/process

import dot_env/env
import filepath.{join}
import mist
import wisp
import wisp/wisp_mist

pub fn main() {
  wisp.configure_logger()

  // TODO: This is a big hack, couldn't find an abs path function
  let assert Ok(pwd) = env.get_string("PWD")
  let assert Ok(settings) = get_settings(join(pwd, ".env"))

  // Start a database connection pool.
  let assert Ok(_conn) = read_connection_uri(settings.db_uri)

  let ctx = Context(static_directory: static_dir())

  let handler = router.handle_request(_, ctx)

  let assert Ok(_) =
    wisp_mist.handler(handler, settings.secret_key)
    |> mist.new
    |> mist.port(settings.port)
    |> mist.start_http

  process.sleep_forever()
}

pub fn static_dir() {
  let assert Ok(priv_directory) = wisp.priv_directory("app")
  priv_directory <> "static"
}
