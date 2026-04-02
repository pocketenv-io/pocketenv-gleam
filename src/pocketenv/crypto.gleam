//// Client-side encryption helpers.
////
//// Sensitive values (secrets, SSH private keys, Tailscale auth keys) are
//// sealed with the server's X25519 public key using NaCl `crypto_box_seal`
//// before transmission.  The server holds the corresponding private key and
//// is the only party that can decrypt the values.

import gleam/bit_array
import gleam/string

/// The server's X25519 public key used for all client-side encryption.
const public_key = "2bf96e12d109e6948046a7803ef1696e12c11f04f20a6ce64dbd4bcd93db9341"

/// Encrypts `message` using NaCl sealed-box with the hardcoded server public key.
/// Returns a URL-safe base64 string with no padding.
pub fn seal(message: String) -> String {
  let pk = decode_hex(public_key)
  let msg = bit_array.from_string(message)
  box_seal(msg, pk)
  |> base64_encode()
  |> string.replace("+", "-")
  |> string.replace("/", "_")
  |> string.replace("=", "")
}

/// Returns a redacted representation of `value` suitable for display.
/// Preserves the first 11 and last 3 characters; replaces the middle with `*`.
pub fn redact(value: String) -> String {
  let len = string.length(value)
  case len > 14 {
    True ->
      string.slice(value, 0, 11)
      <> string.repeat("*", len - 14)
      <> string.slice(value, len - 3, 3)
    False -> string.repeat("*", len)
  }
}

// --- FFI ---

@external(erlang, "enacl", "box_seal")
fn box_seal(message: BitArray, public_key: BitArray) -> BitArray

@external(erlang, "binary", "decode_hex")
fn decode_hex(hex: String) -> BitArray

@external(erlang, "base64", "encode")
fn base64_encode(data: BitArray) -> String
