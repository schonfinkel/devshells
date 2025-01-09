import gleam/bool
import gleam/string_tree

import wisp

pub type Context {
  Context(static_directory: String)
}

/// The middleware stack that the request handler uses. The stack is itself a
/// middleware function!
///
/// Middleware wrap each other, so the request travels through the stack from
/// top to bottom until it reaches the request handler, at which point the
/// response travels back up through the stack.
/// 
/// The middleware used here are the ones that are suitable for use in your
/// typical web application.
/// 
pub fn middleware(
  req: wisp.Request,
  ctx: Context,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  // Permit browsers to simulate methods other than GET and POST using the
  // `_method` query parameter.
  let req = wisp.method_override(req)

  // Log information about the request and response.
  use <- wisp.log_request(req)

  // Return a default 500 response if the request handler crashes.
  use <- default_responses

  // Use context argument
  //    Serve static assets
  use <- wisp.serve_static(req, under: "/static", from: ctx.static_directory)

  // Rewrite HEAD requests to GET requests and return an empty body.
  use req <- wisp.handle_head(req)

  // Handle the request!
  handle_request(req)
}

// Default responses when we get certain codes
pub fn default_responses(handle_request: fn() -> wisp.Response) -> wisp.Response {
  let response = handle_request()

  // The `bool.guard` function is used to return the original request if the
  // body is not `wisp.Empty`.
  use <- bool.guard(when: response.body != wisp.Empty, return: response)

  // You can use any logic to return appropriate responses depending on what is
  // best for your application.
  // I'm going to match on the status code and depending on what it is add
  // different HTML as the body. This is a good option for most applications.
  case response.status {
    404 | 405 ->
      "<h1>There's nothing here</h1>"
      |> string_tree.from_string
      |> wisp.html_body(response, _)

    400 | 422 ->
      "<h1>Bad request</h1>"
      |> string_tree.from_string
      |> wisp.html_body(response, _)

    413 ->
      "<h1>Request entity too large</h1>"
      |> string_tree.from_string
      |> wisp.html_body(response, _)

    500 ->
      "<h1>Internal server error</h1>"
      |> string_tree.from_string
      |> wisp.html_body(response, _)

    // For other status codes redirect to the home page
    _ -> wisp.redirect("/")
  }
}
