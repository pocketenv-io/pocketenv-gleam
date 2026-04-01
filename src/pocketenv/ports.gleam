//// Query exposed ports of a sandbox.
////
//// To expose or unexpose ports use `pocketenv/network`.

import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option, None}
import gleam/result
import pocketenv.{type PocketenvError, JsonDecodeError, do_get}
import pocketenv/sandbox.{type ConnectedSandbox}

/// An exposed port on a sandbox.
pub type Port {
  Port(port: Int, description: Option(String), preview_url: Option(String))
}

/// Lists all currently exposed ports for the sandbox.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(ports) = sb |> ports.list()
/// ```
pub fn list(sb: ConnectedSandbox) -> Result(List(Port), PocketenvError) {
  use body <- result.try(
    do_get(sb.client, "/xrpc/io.pocketenv.sandbox.getExposedPorts", [
      #("id", sb.data.id),
    ]),
  )
  json.parse(body, {
    use ports <- decode.field("ports", decode.list(port_decoder()))
    decode.success(ports)
  })
  |> result.map_error(JsonDecodeError)
}

/// JSON decoder for `Port`.
pub fn port_decoder() -> decode.Decoder(Port) {
  use port <- decode.field("port", decode.int)
  use description <- decode.optional_field(
    "description",
    None,
    decode.optional(decode.string),
  )
  use preview_url <- decode.optional_field(
    "previewUrl",
    None,
    decode.optional(decode.string),
  )
  decode.success(Port(
    port: port,
    description: description,
    preview_url: preview_url,
  ))
}
