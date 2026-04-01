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
import pocketenv.{type PocketenvError, JsonDecodeError, do_get, do_post}
import pocketenv/sandbox.{type ConnectedSandbox}

/// A single environment variable stored in a sandbox.
pub type Variable {
  Variable(id: String, name: String, value: String, created_at: String)
}

/// Lists environment variables for the sandbox.
/// Optionally paginate with `limit` and `offset`.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(vars) = sb |> env.list(None, None)
/// ```
pub fn list(
  sb: ConnectedSandbox,
  limit: Option(Int),
  offset: Option(Int),
) -> Result(List(Variable), PocketenvError) {
  let query = [#("sandboxId", sb.data.id)]
  let query = case limit {
    Some(l) -> list.append(query, [#("limit", int.to_string(l))])
    None -> query
  }
  let query = case offset {
    Some(o) -> list.append(query, [#("offset", int.to_string(o))])
    None -> query
  }
  use body <- result.try(do_get(
    sb.client,
    "/xrpc/io.pocketenv.variable.getVariables",
    query,
  ))
  json.parse(body, {
    use variables <- decode.field("variables", decode.list(variable_decoder()))
    decode.success(variables)
  })
  |> result.map_error(JsonDecodeError)
}

/// Creates or updates an environment variable named `name` with `value`.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(Nil) = sb |> env.put("PORT", "8080")
/// ```
pub fn put(
  sb: ConnectedSandbox,
  name: String,
  value: String,
) -> Result(Nil, PocketenvError) {
  let body =
    json.to_string(
      json.object([
        #(
          "variable",
          json.object([
            #("sandboxId", json.string(sb.data.id)),
            #("name", json.string(name)),
            #("value", json.string(value)),
          ]),
        ),
      ]),
    )
  use _ <- result.try(do_post(
    sb.client,
    "/xrpc/io.pocketenv.variable.addVariable",
    [],
    body,
  ))
  Ok(Nil)
}

/// Deletes the environment variable identified by `id`.
pub fn delete(sb: ConnectedSandbox, id: String) -> Result(Nil, PocketenvError) {
  use _ <- result.try(do_post(
    sb.client,
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
  decode.success(Variable(
    id: id,
    name: name,
    value: value,
    created_at: created_at,
  ))
}
