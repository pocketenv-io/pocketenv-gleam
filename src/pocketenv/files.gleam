//// Manage files stored inside a sandbox.
////
//// Files are written into the sandbox filesystem and can be listed or deleted.

import gleam/dynamic/decode
import gleam/json
import gleam/result
import pocketenv.{type PocketenvError, JsonDecodeError, do_get, do_post}
import pocketenv/sandbox.{type ConnectedSandbox}

/// Metadata for a file stored in a sandbox.
pub type File {
  File(id: String, path: String, created_at: String)
}

/// Lists all files in the sandbox.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(files) = sb |> files.list()
/// ```
pub fn list(sb: ConnectedSandbox) -> Result(List(File), PocketenvError) {
  use body <- result.try(
    do_get(sb.client, "/xrpc/io.pocketenv.file.getFiles", [
      #("sandboxId", sb.data.id),
    ]),
  )
  json.parse(body, {
    use files <- decode.field("files", decode.list(file_decoder()))
    decode.success(files)
  })
  |> result.map_error(JsonDecodeError)
}

/// Writes (or overwrites) a file at `path` with `content`.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(Nil) = sb |> files.write("/app/.env", "PORT=8080\n")
/// ```
pub fn write(
  sb: ConnectedSandbox,
  path: String,
  content: String,
) -> Result(Nil, PocketenvError) {
  let body =
    json.to_string(
      json.object([
        #(
          "file",
          json.object([
            #("sandboxId", json.string(sb.data.id)),
            #("path", json.string(path)),
            #("content", json.string(content)),
          ]),
        ),
      ]),
    )
  use _ <- result.try(do_post(
    sb.client,
    "/xrpc/io.pocketenv.file.addFile",
    [],
    body,
  ))
  Ok(Nil)
}

/// Deletes the file identified by `id`.
pub fn delete(sb: ConnectedSandbox, id: String) -> Result(Nil, PocketenvError) {
  use _ <- result.try(do_post(
    sb.client,
    "/xrpc/io.pocketenv.file.deleteFile",
    [#("id", id)],
    "{}",
  ))
  Ok(Nil)
}

/// JSON decoder for `File`.
pub fn file_decoder() -> decode.Decoder(File) {
  use id <- decode.field("id", decode.string)
  use path <- decode.field("path", decode.string)
  use created_at <- decode.field("createdAt", decode.string)
  decode.success(File(id: id, path: path, created_at: created_at))
}
