//// Manage SSH key pairs attached to a sandbox.
////
//// The private key is encrypted client-side with the server's public key
//// before transmission and is never returned in plaintext.  A redacted
//// display value is stored alongside so users can recognise which key is
//// configured without exposing the full value.

import gleam/dynamic/decode
import gleam/json
import gleam/option.{type Option, None, Some}
import gleam/result
import pocketenv.{type PocketenvError, JsonDecodeError, do_get, do_post}
import pocketenv/crypto
import pocketenv/sandbox.{type ConnectedSandbox}

/// SSH key pair stored in a sandbox.
/// `private_key` is the encrypted ciphertext; `public_key` is plaintext;
/// `redacted` is a display-safe version of the original private key.
pub type SshKeys {
  SshKeys(private_key: String, public_key: String, redacted: String)
}

/// Retrieves the stored SSH keys for the sandbox, if any.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(keys) = sb |> sshkeys.get()
/// ```
pub fn get(sb: ConnectedSandbox) -> Result(Option(SshKeys), PocketenvError) {
  use body <- result.try(
    do_get(sb.client, "/xrpc/io.pocketenv.sandbox.getSshKeys", [
      #("id", sb.data.id),
    ]),
  )
  json.parse(body, {
    use private_key <- decode.optional_field(
      "privateKey",
      None,
      decode.optional(decode.string),
    )
    use public_key <- decode.optional_field(
      "publicKey",
      None,
      decode.optional(decode.string),
    )
    use redacted <- decode.optional_field(
      "redacted",
      None,
      decode.optional(decode.string),
    )
    decode.success(case private_key, public_key {
      Some(priv), Some(pubk) ->
        Some(SshKeys(
          private_key: priv,
          public_key: pubk,
          redacted: option.unwrap(redacted, ""),
        ))
      _, _ -> None
    })
  })
  |> result.map_error(JsonDecodeError)
}

/// Stores an SSH key pair, encrypting `private_key` before transmission.
/// A redacted display value is computed automatically.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(Nil) = sb |> sshkeys.put(private_key, public_key)
/// ```
pub fn put(
  sb: ConnectedSandbox,
  private_key: String,
  public_key: String,
) -> Result(Nil, PocketenvError) {
  let encrypted = crypto.seal(private_key)
  let redacted = crypto.redact(private_key)
  let body =
    json.to_string(
      json.object([
        #("id", json.string(sb.data.id)),
        #("privateKey", json.string(encrypted)),
        #("publicKey", json.string(public_key)),
        #("redacted", json.string(redacted)),
      ]),
    )
  use _ <- result.try(do_post(
    sb.client,
    "/xrpc/io.pocketenv.sandbox.putSshKeys",
    [],
    body,
  ))
  Ok(Nil)
}
