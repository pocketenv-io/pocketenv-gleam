//// Create, list, and restore backups of a sandbox directory.
////
//// Backups let you snapshot a directory inside a running sandbox and restore
//// it later.  All three operations are scoped to a `ConnectedSandbox`.

import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import pocketenv.{type PocketenvError, JsonDecodeError, do_get, do_post}
import pocketenv/sandbox.{type ConnectedSandbox}

/// A point-in-time snapshot of a sandbox directory.
pub type Backup {
  Backup(
    id: String,
    directory: String,
    description: Option(String),
    expires_at: Option(String),
    created_at: String,
  )
}

/// Creates a backup of `directory` inside the sandbox.
/// Optionally set a human-readable `description` and a time-to-live `ttl`
/// (in seconds) after which the backup is automatically deleted.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(Nil) = sb |> backup.create("/app", Some("pre-deploy"), None)
/// ```
pub fn create(
  sb: ConnectedSandbox,
  directory: String,
  description: Option(String),
  ttl: Option(Int),
) -> Result(Nil, PocketenvError) {
  let fields = [#("directory", json.string(directory))]
  let fields = case description {
    Some(d) -> list.append(fields, [#("description", json.string(d))])
    None -> fields
  }
  let fields = case ttl {
    Some(t) -> list.append(fields, [#("ttl", json.int(t))])
    None -> fields
  }
  let body = json.to_string(json.object(fields))
  use _ <- result.try(do_post(
    sb.client,
    "/xrpc/io.pocketenv.sandbox.createBackup",
    [#("id", sb.data.id)],
    body,
  ))
  Ok(Nil)
}

/// Lists all backups associated with the sandbox.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(backups) = sb |> backup.list()
/// ```
pub fn list(sb: ConnectedSandbox) -> Result(List(Backup), PocketenvError) {
  use body <- result.try(
    do_get(sb.client, "/xrpc/io.pocketenv.sandbox.getBackups", [
      #("id", sb.data.id),
    ]),
  )
  json.parse(body, {
    use backups <- decode.field("backups", decode.list(backup_decoder()))
    decode.success(backups)
  })
  |> result.map_error(JsonDecodeError)
}

/// Restores the backup identified by `backup_id` into the sandbox.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(Nil) = sb |> backup.restore("backup-abc123")
/// ```
pub fn restore(
  sb: ConnectedSandbox,
  backup_id: String,
) -> Result(Nil, PocketenvError) {
  let body =
    json.to_string(json.object([#("backupId", json.string(backup_id))]))
  use _ <- result.try(do_post(
    sb.client,
    "/xrpc/io.pocketenv.sandbox.restoreBackup",
    [],
    body,
  ))
  Ok(Nil)
}

/// JSON decoder for `Backup`.
pub fn backup_decoder() -> decode.Decoder(Backup) {
  use id <- decode.field("id", decode.string)
  use directory <- decode.field("directory", decode.string)
  use description <- decode.optional_field(
    "description",
    None,
    decode.optional(decode.string),
  )
  use expires_at <- decode.optional_field(
    "expiresAt",
    None,
    decode.optional(decode.string),
  )
  use created_at <- decode.field("createdAt", decode.string)
  decode.success(Backup(
    id: id,
    directory: directory,
    description: description,
    expires_at: expires_at,
    created_at: created_at,
  ))
}
