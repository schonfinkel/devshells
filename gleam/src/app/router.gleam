import app/models/user.{type User}
import app/web.{type Context}

import gleam/dynamic/decode
import gleam/http.{Get, Post}
import gleam/json
import gleam/result
import gleam/string_tree

import wisp.{type Request, type Response}

/// The HTTP request handler- your application!
pub fn handle_request(req: Request, ctx: Context) -> Response {
  use req <- web.middleware(req, ctx)

  // Wisp doesn't have a special router abstraction, instead we recommend using
  // regular old pattern matching. This is faster than a router, is type safe,
  // and means you don't have to learn or be limited by a special DSL.
  //
  case wisp.path_segments(req) {
    // This matches `/`.
    [] -> home_page(req)

    // This matches `/users`.
    ["users"] -> users(req)

    // This matches all other paths.
    _ -> wisp.not_found()
  }
}

// Decoders
// [1]: https://hexdocs.pm/gleam_stdlib/gleam/dynamic.html
fn user_decoder() -> decode.Decoder(User) {
  use name <- decode.field("name", decode.string)
  use email <- decode.field("email", decode.string)
  decode.success(user.User(name, email, user.Active))
}

fn home_page(req: Request) -> Response {
  // The home page can only be accessed via GET requests, so this middleware is
  // used to return a 405: Method Not Allowed response for all other methods.
  use <- wisp.require_method(req, Get)

  let html = string_tree.from_string("Hello, Joe!")
  wisp.ok()
  |> wisp.html_body(html)
}

fn users(req: Request) -> Response {
  // This handler for `/users` can respond to both GET and POST requests,
  // so we pattern match on the method here.
  case req.method {
    Get -> list_users()
    Post -> create_user(req)
    _ -> wisp.method_not_allowed([Get, Post])
  }
}

fn list_users() -> Response {
  // In a later example we'll show how to read from a database.
  let html = string_tree.from_string("todo")
  wisp.ok()
  |> wisp.html_body(html)
}

fn create_user(req: Request) -> Response {
  // This middleware parses a `Dynamic` value from the request body.
  // It returns an error response if the body is not valid JSON, or
  // if the content-type is not `application/json`, or if the body
  // is too large.
  use json <- wisp.require_json(req)
  let result = {
    // The JSON data can be decoded into a `User` value.
    use user <- result.try(decode.run(json, user_decoder()))

    // And then a JSON response can be created from the user.
    let object =
      json.object([
        #("name", json.string(user.name)),
        #("email", json.string(user.email)),
        #("saved", json.bool(True)),
      ])
    Ok(json.to_string_tree(object))
  }

  // An appropriate response is returned depending on whether the JSON could be
  // successfully handled or not.
  case result {
    Ok(json) -> wisp.json_response(json, 201)

    // In a real application we would probably want to return some JSON error
    // object, but for this example we'll just return an empty response.
    Error(_) -> wisp.unprocessable_entity()
  }
}
