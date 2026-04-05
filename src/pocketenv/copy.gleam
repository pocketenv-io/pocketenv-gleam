//// Transfer files between your local machine and a sandbox, or between two
//// sandboxes.
////
//// - `upload` — local path → sandbox path
//// - `download` — sandbox path → local directory
//// - `copy_to` — sandbox path → another sandbox path (no local I/O)

import gleam/bit_array
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/json
import gleam/result
import gleam/string
import pocketenv.{
  type Client, type PocketenvError, ApiError, HttpError, JsonDecodeError,
  RequestBuildError, do_post,
}
import pocketenv/sandbox.{type ConnectedSandbox}

// ---------------------------------------------------------------------------
// Erlang FFI
// ---------------------------------------------------------------------------

@external(erlang, "pocketenv_copy_ffi", "temp_path")
fn temp_path() -> String

@external(erlang, "pocketenv_copy_ffi", "compress")
fn compress_ffi(source_path: String) -> Result(String, String)

@external(erlang, "pocketenv_copy_ffi", "decompress")
fn decompress_ffi(archive_path: String, dest_path: String) -> Result(Nil, String)

@external(erlang, "pocketenv_copy_ffi", "read_file")
fn read_file(path: String) -> Result(BitArray, String)

@external(erlang, "pocketenv_copy_ffi", "write_file")
fn write_file(path: String, data: BitArray) -> Result(Nil, String)

@external(erlang, "pocketenv_copy_ffi", "delete_file")
fn delete_file(path: String) -> Nil

@external(erlang, "pocketenv_copy_ffi", "random_hex")
fn random_hex(n: Int) -> String

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Asks the sandbox to compress `directory_path` into storage.
/// Returns the UUID of the stored archive.
fn push_directory(
  client: Client,
  sandbox_id: String,
  directory_path: String,
) -> Result(String, PocketenvError) {
  let body =
    json.to_string(json.object([
      #("sandboxId", json.string(sandbox_id)),
      #("directoryPath", json.string(directory_path)),
    ]))
  use resp_body <- result.try(do_post(
    client,
    "/xrpc/io.pocketenv.sandbox.pushDirectory",
    [],
    body,
  ))
  json.parse(resp_body, {
    use uuid <- decode.field("uuid", decode.string)
    decode.success(uuid)
  })
  |> result.map_error(JsonDecodeError)
}

/// Tells the sandbox to pull an archive (identified by `uuid`) into
/// `directory_path`.
fn pull_directory(
  client: Client,
  sandbox_id: String,
  uuid: String,
  directory_path: String,
) -> Result(Nil, PocketenvError) {
  let body =
    json.to_string(json.object([
      #("uuid", json.string(uuid)),
      #("sandboxId", json.string(sandbox_id)),
      #("directoryPath", json.string(directory_path)),
    ]))
  use _ <- result.try(do_post(
    client,
    "/xrpc/io.pocketenv.sandbox.pullDirectory",
    [],
    body,
  ))
  Ok(Nil)
}

/// Uploads a local tar.gz archive to storage as multipart/form-data.
/// Returns the UUID assigned to the stored archive.
fn upload_to_storage(
  archive_path: String,
  token: String,
  storage_url: String,
) -> Result(String, PocketenvError) {
  use content <- result.try(read_file(archive_path) |> result.map_error(HttpError))
  let boundary = "FormBoundary" <> random_hex(8)
  let crlf = "\r\n"
  let body =
    bit_array.concat([
      bit_array.from_string(
        "--"
        <> boundary
        <> crlf
        <> "Content-Disposition: form-data; name=\"file\"; filename=\"archive.tar.gz\""
        <> crlf
        <> "Content-Type: application/gzip"
        <> crlf
        <> crlf,
      ),
      content,
      bit_array.from_string(crlf <> "--" <> boundary <> "--" <> crlf),
    ])
  let url = storage_url <> "/cp"
  use base_req <- result.try(
    request.to(url) |> result.replace_error(RequestBuildError),
  )
  let req =
    base_req
    |> request.set_body(body)
    |> request.set_method(http.Post)
    |> request.prepend_header("authorization", "Bearer " <> token)
    |> request.prepend_header(
      "content-type",
      "multipart/form-data; boundary=" <> boundary,
    )
  use resp <- result.try(
    httpc.send_bits(req)
    |> result.map_error(fn(e) { HttpError(string.inspect(e)) }),
  )
  case resp.status {
    s if s >= 200 && s < 300 -> {
      use body_str <- result.try(
        bit_array.to_string(resp.body)
        |> result.replace_error(HttpError("invalid UTF-8 in storage response")),
      )
      json.parse(body_str, {
        use uuid <- decode.field("uuid", decode.string)
        decode.success(uuid)
      })
      |> result.map_error(JsonDecodeError)
    }
    s -> Error(ApiError(s))
  }
}

/// Downloads an archive from storage by UUID, writing it to `dest_path`.
fn download_from_storage(
  uuid: String,
  dest_path: String,
  token: String,
  storage_url: String,
) -> Result(Nil, PocketenvError) {
  let url = storage_url <> "/cp/" <> uuid
  use base_req <- result.try(
    request.to(url) |> result.replace_error(RequestBuildError),
  )
  let req =
    base_req
    |> request.set_body(<<>>)
    |> request.set_method(http.Get)
    |> request.prepend_header("authorization", "Bearer " <> token)
  use resp <- result.try(
    httpc.send_bits(req)
    |> result.map_error(fn(e) { HttpError(string.inspect(e)) }),
  )
  case resp.status {
    s if s >= 200 && s < 300 ->
      write_file(dest_path, resp.body) |> result.map_error(HttpError)
    s -> Error(ApiError(s))
  }
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Uploads a local file or directory to `sandbox_path` inside the sandbox.
///
/// The local path is compressed into a tar.gz archive, uploaded to storage,
/// and then extracted by the sandbox at the specified destination path.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(Nil) = sb |> copy.upload("./dist", "/app/dist")
/// ```
pub fn upload(
  sb: ConnectedSandbox,
  local_path: String,
  sandbox_path: String,
) -> Result(Nil, PocketenvError) {
  use archive <- result.try(
    compress_ffi(local_path) |> result.map_error(HttpError),
  )
  let upload_result =
    upload_to_storage(archive, sb.client.token, sb.client.storage_url)
  let _ = delete_file(archive)
  use uuid <- result.try(upload_result)
  pull_directory(sb.client, sb.data.id, uuid, sandbox_path)
}

/// Downloads `sandbox_path` from the sandbox to the local `local_path`
/// directory.
///
/// The sandbox compresses the source path, which is then downloaded and
/// extracted locally.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(Nil) = sb |> copy.download("/app/logs", "./logs")
/// ```
pub fn download(
  sb: ConnectedSandbox,
  sandbox_path: String,
  local_path: String,
) -> Result(Nil, PocketenvError) {
  use uuid <- result.try(push_directory(sb.client, sb.data.id, sandbox_path))
  let archive = temp_path()
  let result = {
    use _ <- result.try(
      download_from_storage(uuid, archive, sb.client.token, sb.client.storage_url),
    )
    decompress_ffi(archive, local_path) |> result.map_error(HttpError)
  }
  let _ = delete_file(archive)
  result
}

/// Copies `src_path` from this sandbox into `dest_path` on `dest_sandbox_id`.
///
/// No local I/O is involved — the transfer goes directly through storage.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(Nil) = sb |> copy.copy_to(other_id, "/app/data", "/app/data")
/// ```
pub fn copy_to(
  sb: ConnectedSandbox,
  dest_sandbox_id: String,
  src_path: String,
  dest_path: String,
) -> Result(Nil, PocketenvError) {
  use uuid <- result.try(push_directory(sb.client, sb.data.id, src_path))
  pull_directory(sb.client, dest_sandbox_id, uuid, dest_path)
}
