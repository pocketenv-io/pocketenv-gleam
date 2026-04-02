# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-04-02

### Added

- `pocketenv/crypto` module with `seal/1` (NaCl sealed-box encryption via libsodium) and `redact/1` (display-safe masking)
- `pocketenv/sshkeys` module with `get/1` and `put/3` — private keys are encrypted before transmission and a redacted display value is stored alongside
- `secrets.put/3` now encrypts the secret value client-side before sending
- `network.setup_tailscale/2` now encrypts the auth key and stores a redacted display value
- `network.get_tailscale_auth_key/1` now returns the redacted display value
- `enacl` dependency for Erlang libsodium NIF bindings

## [1.0.0] - 2026-04-01

### Added

- Initial Pocketenv Gleam client library
- `new_client` function for creating a configured HTTP client
- Sandbox API support via `ConnectedSandbox`
- JSON-based request/response handling using `gleam_json`
- HTTP client integration via `gleam_http` and `gleam_httpc`
