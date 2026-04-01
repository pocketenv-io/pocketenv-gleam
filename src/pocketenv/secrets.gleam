//// Manage encrypted secrets attached to a sandbox.
////
//// Secrets are similar to environment variables but their values are write-only:
//// the API never returns the stored value. Use them for API keys, passwords, and
//// other sensitive data.

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import pocketenv.{
  type Client, type PocketenvError, JsonDecodeError, do_get, do_post,
}

/// A secret stored in a sandbox. Only the `name` is exposed; the value is never returned.
pub type Secret {
  Secret(id: String, name: String, created_at: String)
}

/// Lists secret names for `sandbox_id`. Optionally paginate with `limit` and `offset`.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(secrets) = secrets.list(client, sandbox_id, None, None)
/// ```
pub fn list(
  client: Client,
  sandbox_id: String,
  limit: Option(Int),
  offset: Option(Int),
) -> Result(List(Secret), PocketenvError) {
  let query = [#("sandboxId", sandbox_id)]
  let query = case limit {
    Some(l) -> list.append(query, [#("limit", int.to_string(l))])
    None -> query
  }
  let query = case offset {
    Some(o) -> list.append(query, [#("offset", int.to_string(o))])
    None -> query
  }
  use body <- result.try(do_get(
    client,
    "/xrpc/io.pocketenv.secret.getSecrets",
    query,
  ))
  json.parse(body, {
    use secrets <- decode.field("secrets", decode.list(secret_decoder()))
    decode.success(secrets)
  })
  |> result.map_error(JsonDecodeError)
}

/// Creates or updates a secret named `name` with `value` in `sandbox_id`.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(Nil) = secrets.put(client, sandbox_id, "DB_PASSWORD", "s3cr3t")
/// ```
pub fn put(
  client: Client,
  sandbox_id: String,
  name: String,
  value: String,
) -> Result(Nil, PocketenvError) {
  let body =
    json.to_string(
      json.object([
        #(
          "secret",
          json.object([
            #("sandboxId", json.string(sandbox_id)),
            #("name", json.string(name)),
            #("value", json.string(value)),
          ]),
        ),
      ]),
    )
  use _ <- result.try(do_post(
    client,
    "/xrpc/io.pocketenv.secret.addSecret",
    [],
    body,
  ))
  Ok(Nil)
}

/// Deletes the secret identified by `id`.
pub fn delete(client: Client, id: String) -> Result(Nil, PocketenvError) {
  use _ <- result.try(do_post(
    client,
    "/xrpc/io.pocketenv.secret.deleteSecret",
    [#("id", id)],
    "{}",
  ))
  Ok(Nil)
}

/// JSON decoder for `Secret`.
pub fn secret_decoder() -> decode.Decoder(Secret) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use created_at <- decode.field("createdAt", decode.string)
  decode.success(Secret(id: id, name: name, created_at: created_at))
}
