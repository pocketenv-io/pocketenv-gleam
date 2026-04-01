//// Manage persistent volumes mounted in a sandbox.
////
//// Volumes provide durable storage that survives sandbox restarts.

import gleam/dynamic/decode
import gleam/json
import gleam/result
import pocketenv.{type PocketenvError, JsonDecodeError, do_get, do_post}
import pocketenv/sandbox.{type ConnectedSandbox}

/// A persistent volume mounted in a sandbox.
pub type Volume {
  Volume(id: String, name: String, path: String, created_at: String)
}

/// Lists all volumes attached to the sandbox.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(vols) = sb |> volume.list()
/// ```
pub fn list(sb: ConnectedSandbox) -> Result(List(Volume), PocketenvError) {
  use body <- result.try(
    do_get(sb.client, "/xrpc/io.pocketenv.volume.getVolumes", [
      #("sandboxId", sb.data.id),
    ]),
  )
  json.parse(body, {
    use volumes <- decode.field("volumes", decode.list(volume_decoder()))
    decode.success(volumes)
  })
  |> result.map_error(JsonDecodeError)
}

/// Creates a volume named `name` mounted at `path`.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(Nil) = sb |> volume.create("data", "/mnt/data")
/// ```
pub fn create(
  sb: ConnectedSandbox,
  name: String,
  path: String,
) -> Result(Nil, PocketenvError) {
  let body =
    json.to_string(
      json.object([
        #(
          "volume",
          json.object([
            #("sandboxId", json.string(sb.data.id)),
            #("name", json.string(name)),
            #("path", json.string(path)),
          ]),
        ),
      ]),
    )
  use _ <- result.try(do_post(
    sb.client,
    "/xrpc/io.pocketenv.volume.addVolume",
    [],
    body,
  ))
  Ok(Nil)
}

/// Deletes the volume identified by `id`.
pub fn delete(sb: ConnectedSandbox, id: String) -> Result(Nil, PocketenvError) {
  use _ <- result.try(do_post(
    sb.client,
    "/xrpc/io.pocketenv.volume.deleteVolume",
    [#("id", id)],
    "{}",
  ))
  Ok(Nil)
}

/// JSON decoder for `Volume`.
pub fn volume_decoder() -> decode.Decoder(Volume) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use path <- decode.field("path", decode.string)
  use created_at <- decode.field("createdAt", decode.string)
  decode.success(Volume(id: id, name: name, path: path, created_at: created_at))
}
