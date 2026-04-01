//// Manage persistent volumes mounted in a sandbox.
////
//// Volumes provide durable storage that survives sandbox restarts.

import gleam/dynamic/decode
import gleam/json
import gleam/result
import pocketenv.{
  type Client, type PocketenvError, JsonDecodeError, do_get, do_post,
}

/// A persistent volume mounted in a sandbox.
pub type Volume {
  Volume(id: String, name: String, path: String, created_at: String)
}

/// Lists all volumes attached to `sandbox_id`.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(vols) = volume.list(client, sandbox_id)
/// ```
pub fn list(
  client: Client,
  sandbox_id: String,
) -> Result(List(Volume), PocketenvError) {
  use body <- result.try(
    do_get(client, "/xrpc/io.pocketenv.volume.getVolumes", [
      #("sandboxId", sandbox_id),
    ]),
  )
  json.parse(body, {
    use volumes <- decode.field("volumes", decode.list(volume_decoder()))
    decode.success(volumes)
  })
  |> result.map_error(JsonDecodeError)
}

/// Creates a volume named `name` mounted at `path` in `sandbox_id`.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(Nil) = volume.create(client, sandbox_id, "data", "/mnt/data")
/// ```
pub fn create(
  client: Client,
  sandbox_id: String,
  name: String,
  path: String,
) -> Result(Nil, PocketenvError) {
  let body =
    json.to_string(
      json.object([
        #(
          "volume",
          json.object([
            #("sandboxId", json.string(sandbox_id)),
            #("name", json.string(name)),
            #("path", json.string(path)),
          ]),
        ),
      ]),
    )
  use _ <- result.try(do_post(
    client,
    "/xrpc/io.pocketenv.volume.addVolume",
    [],
    body,
  ))
  Ok(Nil)
}

/// Deletes the volume identified by `id`.
pub fn delete(client: Client, id: String) -> Result(Nil, PocketenvError) {
  use _ <- result.try(do_post(
    client,
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
