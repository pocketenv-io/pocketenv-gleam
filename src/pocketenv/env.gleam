//// Manage environment variables attached to a sandbox.
////
//// Variables are plain-text key/value pairs injected into the sandbox at
//// runtime. For sensitive data prefer `pocketenv/secrets`.

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import pocketenv.{
  type Client, type PocketenvError, JsonDecodeError, do_get, do_post,
}

/// A single environment variable stored in a sandbox.
pub type Variable {
  Variable(id: String, name: String, value: String, created_at: String)
}

/// Lists environment variables for `sandbox_id`.
/// Optionally paginate with `limit` and `offset`.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(vars) = env.list(client, sandbox_id, None, None)
/// ```
pub fn list(
  client: Client,
  sandbox_id: String,
  limit: Option(Int),
  offset: Option(Int),
) -> Result(List(Variable), PocketenvError) {
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
    "/xrpc/io.pocketenv.variable.getVariables",
    query,
  ))
  json.parse(body, {
    use variables <- decode.field("variables", decode.list(variable_decoder()))
    decode.success(variables)
  })
  |> result.map_error(JsonDecodeError)
}

/// Creates or updates an environment variable named `name` with `value` in `sandbox_id`.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(Nil) = env.put(client, sandbox_id, "PORT", "8080")
/// ```
pub fn put(
  client: Client,
  sandbox_id: String,
  name: String,
  value: String,
) -> Result(Nil, PocketenvError) {
  let body =
    json.to_string(json.object([
      #(
        "variable",
        json.object([
          #("sandboxId", json.string(sandbox_id)),
          #("name", json.string(name)),
          #("value", json.string(value)),
        ]),
      ),
    ]))
  use _ <- result.try(do_post(
    client,
    "/xrpc/io.pocketenv.variable.addVariable",
    [],
    body,
  ))
  Ok(Nil)
}

/// Deletes the environment variable identified by `id`.
pub fn delete(client: Client, id: String) -> Result(Nil, PocketenvError) {
  use _ <- result.try(do_post(
    client,
    "/xrpc/io.pocketenv.variable.deleteVariable",
    [#("id", id)],
    "{}",
  ))
  Ok(Nil)
}

/// JSON decoder for `Variable`.
pub fn variable_decoder() -> decode.Decoder(Variable) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use value <- decode.field("value", decode.string)
  use created_at <- decode.field("createdAt", decode.string)
  decode.success(Variable(id: id, name: name, value: value, created_at: created_at))
}
