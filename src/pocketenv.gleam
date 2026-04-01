//// Core types and HTTP helpers for the Pocketenv API client.
////
//// Start by creating a `Client` with `new_client/2`, then pass it to any
//// of the sub-module functions (`sandbox`, `env`, `secrets`, `files`, etc.).

import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/json
import gleam/option.{type Option, None}
import gleam/result
import gleam/string

/// Holds the base URL and bearer token used for every API request.
pub type Client {
  Client(base_url: String, token: String)
}

/// Errors that can be returned by any API call.
pub type PocketenvError {
  /// An HTTP-level error (connection failure, timeout, etc.).
  HttpError(String)
  /// The response body could not be decoded as expected JSON.
  JsonDecodeError(json.DecodeError)
  /// The server returned a non-2xx status code.
  ApiError(Int)
  /// The request URL could not be constructed (malformed base URL).
  RequestBuildError
}

/// Information about the authenticated actor (user/bot).
pub type Profile {
  Profile(
    id: Option(String),
    did: String,
    handle: String,
    display_name: Option(String),
    avatar: Option(String),
    created_at: Option(String),
    updated_at: Option(String),
  )
}

/// The default base URL for the Pocketenv API.
pub const default_base_url = "https://api.pocketenv.io"

/// Creates a new API client using the default base URL (`https://api.pocketenv.io`).
///
/// ## Example
///
/// ```gleam
/// let client = pocketenv.new_client("your-token")
/// ```
pub fn new_client(token: String) -> Client {
  Client(base_url: default_base_url, token: token)
}

/// Creates a new API client with a custom base URL.
///
/// ## Example
///
/// ```gleam
/// let client = pocketenv.new_client_with_base_url("https://self-hosted.example.com", "your-token")
/// ```
pub fn new_client_with_base_url(base_url: String, token: String) -> Client {
  Client(base_url: base_url, token: token)
}

/// Fetches the profile of the authenticated actor.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(profile) = pocketenv.get_profile(client)
/// io.println(profile.handle)
/// ```
pub fn get_profile(client: Client) -> Result(Profile, PocketenvError) {
  use body <- result.try(
    do_get(client, "/xrpc/io.pocketenv.actor.getProfile", []),
  )
  json.parse(body, profile_decoder())
  |> result.map_error(JsonDecodeError)
}

/// JSON decoder for `Profile`. Useful when embedding profile data in custom decoders.
pub fn profile_decoder() -> decode.Decoder(Profile) {
  use id <- decode.optional_field("id", None, decode.optional(decode.string))
  use did <- decode.field("did", decode.string)
  use handle <- decode.field("handle", decode.string)
  use display_name <- decode.optional_field(
    "displayName",
    None,
    decode.optional(decode.string),
  )
  use avatar <- decode.optional_field(
    "avatar",
    None,
    decode.optional(decode.string),
  )
  use created_at <- decode.optional_field(
    "createdAt",
    None,
    decode.optional(decode.string),
  )
  use updated_at <- decode.optional_field(
    "updatedAt",
    None,
    decode.optional(decode.string),
  )
  decode.success(Profile(
    id: id,
    did: did,
    handle: handle,
    display_name: display_name,
    avatar: avatar,
    created_at: created_at,
    updated_at: updated_at,
  ))
}

/// Sends an authenticated GET request to `path` with optional query params.
/// Returns the raw response body on success.
pub fn do_get(
  client: Client,
  path: String,
  query: List(#(String, String)),
) -> Result(String, PocketenvError) {
  let url = client.base_url <> path
  use req <- result.try(
    request.to(url) |> result.replace_error(RequestBuildError),
  )
  let req =
    req
    |> request.set_method(http.Get)
    |> request.prepend_header("authorization", "Bearer " <> client.token)
  let req = case query {
    [] -> req
    q -> request.set_query(req, q)
  }
  use resp <- result.try(
    httpc.send(req)
    |> result.map_error(fn(e) { HttpError(string.inspect(e)) }),
  )
  case resp.status {
    s if s >= 200 && s < 300 -> Ok(resp.body)
    s -> Error(ApiError(s))
  }
}

/// Sends an authenticated POST request to `path` with an optional query and a
/// JSON `body`. Returns the raw response body on success.
pub fn do_post(
  client: Client,
  path: String,
  query: List(#(String, String)),
  body: String,
) -> Result(String, PocketenvError) {
  let url = client.base_url <> path
  use req <- result.try(
    request.to(url) |> result.replace_error(RequestBuildError),
  )
  let req =
    req
    |> request.set_method(http.Post)
    |> request.prepend_header("authorization", "Bearer " <> client.token)
    |> request.prepend_header("content-type", "application/json")
    |> request.set_body(body)
  let req = case query {
    [] -> req
    q -> request.set_query(req, q)
  }
  use resp <- result.try(
    httpc.send(req)
    |> result.map_error(fn(e) { HttpError(string.inspect(e)) }),
  )
  case resp.status {
    s if s >= 200 && s < 300 -> Ok(resp.body)
    s -> Error(ApiError(s))
  }
}
