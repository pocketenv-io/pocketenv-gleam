//// Manage long-running services inside a sandbox.
////
//// A service is a named process (e.g. a web server or background worker) that
//// the platform can start, stop, and restart independently.

import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import pocketenv.{
  type Client, type PocketenvError, JsonDecodeError, do_get, do_post,
}

/// A service running (or registered to run) inside a sandbox.
pub type Service {
  Service(
    id: String,
    name: String,
    command: String,
    ports: Option(List(Int)),
    description: Option(String),
    status: String,
    created_at: String,
  )
}

/// Lists all services registered in `sandbox_id`.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(svcs) = services.list(client, sandbox_id)
/// ```
pub fn list(
  client: Client,
  sandbox_id: String,
) -> Result(List(Service), PocketenvError) {
  use body <- result.try(
    do_get(client, "/xrpc/io.pocketenv.service.getServices", [
      #("sandboxId", sandbox_id),
    ]),
  )
  json.parse(body, {
    use services <- decode.field("services", decode.list(service_decoder()))
    decode.success(services)
  })
  |> result.map_error(JsonDecodeError)
}

/// Registers a new service in `sandbox_id`.
///
/// - `name` — unique name for the service
/// - `command` — shell command to run
/// - `ports` — optional list of ports the service listens on
/// - `description` — optional human-readable description
///
/// ## Example
///
/// ```gleam
/// let assert Ok(Nil) =
///   services.create(client, sandbox_id, "api", "node server.js", Some([3000]), None)
/// ```
pub fn create(
  client: Client,
  sandbox_id: String,
  name: String,
  command: String,
  ports: Option(List(Int)),
  description: Option(String),
) -> Result(Nil, PocketenvError) {
  let service_fields = [
    #("name", json.string(name)),
    #("command", json.string(command)),
  ]
  let service_fields = case ports {
    Some(ps) ->
      list.append(service_fields, [#("ports", json.array(ps, json.int))])
    None -> service_fields
  }
  let service_fields = case description {
    Some(d) -> list.append(service_fields, [#("description", json.string(d))])
    None -> service_fields
  }
  let body =
    json.to_string(json.object([#("service", json.object(service_fields))]))
  use _ <- result.try(do_post(
    client,
    "/xrpc/io.pocketenv.service.addService",
    [#("sandboxId", sandbox_id)],
    body,
  ))
  Ok(Nil)
}

/// Starts the service identified by `service_id`.
pub fn start(client: Client, service_id: String) -> Result(Nil, PocketenvError) {
  use _ <- result.try(do_post(
    client,
    "/xrpc/io.pocketenv.service.startService",
    [#("serviceId", service_id)],
    "{}",
  ))
  Ok(Nil)
}

/// Stops the service identified by `service_id`.
pub fn stop(client: Client, service_id: String) -> Result(Nil, PocketenvError) {
  use _ <- result.try(do_post(
    client,
    "/xrpc/io.pocketenv.service.stopService",
    [#("serviceId", service_id)],
    "{}",
  ))
  Ok(Nil)
}

/// Restarts the service identified by `service_id`.
pub fn restart(
  client: Client,
  service_id: String,
) -> Result(Nil, PocketenvError) {
  use _ <- result.try(do_post(
    client,
    "/xrpc/io.pocketenv.service.restartService",
    [#("serviceId", service_id)],
    "{}",
  ))
  Ok(Nil)
}

/// Deletes the service identified by `service_id`.
pub fn delete(client: Client, service_id: String) -> Result(Nil, PocketenvError) {
  use _ <- result.try(do_post(
    client,
    "/xrpc/io.pocketenv.service.deleteService",
    [#("serviceId", service_id)],
    "{}",
  ))
  Ok(Nil)
}

/// JSON decoder for `Service`.
pub fn service_decoder() -> decode.Decoder(Service) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use command <- decode.field("command", decode.string)
  use ports <- decode.optional_field(
    "ports",
    None,
    decode.optional(decode.list(decode.int)),
  )
  use description <- decode.optional_field(
    "description",
    None,
    decode.optional(decode.string),
  )
  use status <- decode.field("status", decode.string)
  use created_at <- decode.field("createdAt", decode.string)
  decode.success(Service(
    id: id,
    name: name,
    command: command,
    ports: ports,
    description: description,
    status: status,
    created_at: created_at,
  ))
}
