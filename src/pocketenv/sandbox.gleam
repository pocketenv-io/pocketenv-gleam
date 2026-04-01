//// Create, manage, and interact with Pocketenv sandboxes.
////
//// A sandbox is an isolated cloud environment that can run commands, expose
//// ports, and host services. All other resources (env vars, secrets, files,
//// volumes, services) are attached to a sandbox.

import gleam/dynamic/decode
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import pocketenv.{
  type Client, type PocketenvError, JsonDecodeError, do_get, do_post,
}

/// Full details of a Pocketenv sandbox.
pub type Sandbox {
  Sandbox(
    id: String,
    name: String,
    provider: Option(String),
    base_sandbox: Option(String),
    display_name: Option(String),
    uri: Option(String),
    description: Option(String),
    topics: Option(List(String)),
    logo: Option(String),
    readme: Option(String),
    repo: Option(String),
    vcpus: Option(Int),
    memory: Option(Int),
    disk: Option(Int),
    installs: Option(Int),
    status: Option(String),
    started_at: Option(String),
    created_at: String,
  )
}

/// A sandbox bundled with its client — returned by `create` and `connect`.
/// All operations (`start`, `stop`, `exec`, …) work directly on this type.
pub type ConnectedSandbox {
  ConnectedSandbox(data: Sandbox, client: Client)
}

/// The output of a command executed inside a sandbox.
pub type ExecResult {
  ExecResult(stdout: String, stderr: String, exit_code: Int)
}

/// A builder for configuring a new sandbox before calling `create`.
pub opaque type SandboxBuilder {
  SandboxBuilder(
    client: Client,
    name: String,
    base: String,
    provider: String,
    repo: Option(String),
    description: Option(String),
  )
}

/// Starts a sandbox builder with the three required fields.
/// Chain optional `with_*` setters then call `create()`.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(sb) =
///   client
///   |> sandbox.new("my-app", "openclaw", "cloudflare")
///   |> sandbox.with_description("My app sandbox")
///   |> sandbox.create()
/// ```
pub fn new(
  client: Client,
  name: String,
  base: String,
  provider: String,
) -> SandboxBuilder {
  SandboxBuilder(
    client: client,
    name: name,
    base: base,
    provider: provider,
    repo: None,
    description: None,
  )
}

/// Sets the Git repo URL to clone when the sandbox starts.
pub fn with_repo(builder: SandboxBuilder, repo: String) -> SandboxBuilder {
  SandboxBuilder(..builder, repo: Some(repo))
}

/// Sets a human-readable description for the sandbox.
pub fn with_description(
  builder: SandboxBuilder,
  description: String,
) -> SandboxBuilder {
  SandboxBuilder(..builder, description: Some(description))
}

/// Creates the sandbox and returns a `ConnectedSandbox` ready for use.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(sb) =
///   client
///   |> sandbox.new("my-app", "openclaw", "cloudflare")
///   |> sandbox.create()
///
/// sb |> sandbox.start(None, None)
/// sb |> sandbox.exec("echo hello")
/// sb |> sandbox.stop()
/// ```
pub fn create(
  builder: SandboxBuilder,
) -> Result(ConnectedSandbox, PocketenvError) {
  let fields = [
    #("name", json.string(builder.name)),
    #("base", json.string(builder.base)),
    #("provider", json.string(builder.provider)),
  ]
  let fields = case builder.repo {
    Some(r) -> list.append(fields, [#("repo", json.string(r))])
    None -> fields
  }
  let fields = case builder.description {
    Some(d) -> list.append(fields, [#("description", json.string(d))])
    None -> fields
  }
  let body = json.to_string(json.object(fields))
  use resp_body <- result.try(do_post(
    builder.client,
    "/xrpc/io.pocketenv.sandbox.createSandbox",
    [],
    body,
  ))
  use sb <- result.try(
    json.parse(resp_body, sandbox_decoder())
    |> result.map_error(JsonDecodeError),
  )
  Ok(ConnectedSandbox(data: sb, client: builder.client))
}

/// Wraps a `Sandbox` obtained from `get`/`list` with a client, producing a
/// `ConnectedSandbox` that can be passed to `start`, `stop`, `exec`, etc.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(#(sandboxes, _)) = sandbox.list(client, None, None)
/// let assert [first, ..] = sandboxes
/// let sb = first |> sandbox.connect(client)
/// sb |> sandbox.exec("ls")
/// ```
pub fn connect(sandbox: Sandbox, client: Client) -> ConnectedSandbox {
  ConnectedSandbox(data: sandbox, client: client)
}

/// Fetches a single sandbox by `id`. Returns `None` if not found.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(Some(sb)) = sandbox.get(client, "sandbox-abc123")
/// ```
pub fn get(
  client: Client,
  id: String,
) -> Result(Option(Sandbox), PocketenvError) {
  use body <- result.try(
    do_get(client, "/xrpc/io.pocketenv.sandbox.getSandbox", [#("id", id)]),
  )
  json.parse(body, {
    use sandbox <- decode.optional_field(
      "sandbox",
      None,
      decode.optional(sandbox_decoder()),
    )
    decode.success(sandbox)
  })
  |> result.map_error(JsonDecodeError)
}

/// Lists sandboxes visible to the authenticated actor.
/// Returns a tuple of `#(sandboxes, total_count)`.
/// Optionally paginate with `limit` and `offset`.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(#(sandboxes, total)) = sandbox.list(client, Some(10), None)
/// ```
pub fn list(
  client: Client,
  limit: Option(Int),
  offset: Option(Int),
) -> Result(#(List(Sandbox), Int), PocketenvError) {
  let query = []
  let query = case limit {
    Some(l) -> list.append(query, [#("limit", int.to_string(l))])
    None -> query
  }
  let query = case offset {
    Some(o) -> list.append(query, [#("offset", int.to_string(o))])
    None -> query
  }
  use body <- result.try(do_get(
    client,
    "/xrpc/io.pocketenv.sandbox.getSandboxes",
    query,
  ))
  json.parse(body, {
    use sandboxes <- decode.field("sandboxes", decode.list(sandbox_decoder()))
    use total <- decode.optional_field(
      "total",
      None,
      decode.optional(decode.int),
    )
    decode.success(#(sandboxes, option.unwrap(total, 0)))
  })
  |> result.map_error(JsonDecodeError)
}

/// Lists sandboxes owned by the actor identified by `did`.
pub fn get_actor_sandboxes(
  client: Client,
  did: String,
  limit: Option(Int),
  offset: Option(Int),
) -> Result(List(Sandbox), PocketenvError) {
  let query = [#("did", did)]
  let query = case limit {
    Some(l) -> list.append(query, [#("limit", int.to_string(l))])
    None -> query
  }
  let query = case offset {
    Some(o) -> list.append(query, [#("offset", int.to_string(o))])
    None -> query
  }
  use body <- result.try(do_get(
    client,
    "/xrpc/io.pocketenv.actor.getActorSandboxes",
    query,
  ))
  json.parse(body, {
    use sandboxes <- decode.field("sandboxes", decode.list(sandbox_decoder()))
    decode.success(sandboxes)
  })
  |> result.map_error(JsonDecodeError)
}

/// Starts the sandbox.
/// Optionally clone a `repo` on start and keep the sandbox alive with `keep_alive`.
///
/// ## Example
///
/// ```gleam
/// sb |> sandbox.start(None, Some(True))
/// ```
pub fn start(
  sb: ConnectedSandbox,
  repo: Option(String),
  keep_alive: Option(Bool),
) -> Result(Nil, PocketenvError) {
  let fields = case repo {
    Some(r) -> [#("repo", json.string(r))]
    None -> []
  }
  let fields = case keep_alive {
    Some(k) -> list.append(fields, [#("keepAlive", json.bool(k))])
    None -> fields
  }
  let body = json.to_string(json.object(fields))
  use _ <- result.try(do_post(
    sb.client,
    "/xrpc/io.pocketenv.sandbox.startSandbox",
    [#("id", sb.data.id)],
    body,
  ))
  Ok(Nil)
}

/// Stops the sandbox.
///
/// ## Example
///
/// ```gleam
/// sb |> sandbox.stop()
/// ```
pub fn stop(sb: ConnectedSandbox) -> Result(Nil, PocketenvError) {
  use _ <- result.try(do_post(
    sb.client,
    "/xrpc/io.pocketenv.sandbox.stopSandbox",
    [#("id", sb.data.id)],
    "{}",
  ))
  Ok(Nil)
}

/// Permanently deletes the sandbox.
///
/// ## Example
///
/// ```gleam
/// sb |> sandbox.delete()
/// ```
pub fn delete(sb: ConnectedSandbox) -> Result(Nil, PocketenvError) {
  use _ <- result.try(do_post(
    sb.client,
    "/xrpc/io.pocketenv.sandbox.deleteSandbox",
    [#("id", sb.data.id)],
    "{}",
  ))
  Ok(Nil)
}

/// Executes a shell `command` inside the running sandbox.
/// Returns stdout, stderr, and the exit code.
///
/// ## Example
///
/// ```gleam
/// let assert Ok(res) = sb |> sandbox.exec("ls /app")
/// io.println(res.stdout)
/// ```
pub fn exec(
  sb: ConnectedSandbox,
  command: String,
) -> Result(ExecResult, PocketenvError) {
  let body = json.to_string(json.object([#("command", json.string(command))]))
  use resp_body <- result.try(do_post(
    sb.client,
    "/xrpc/io.pocketenv.sandbox.exec",
    [#("id", sb.data.id)],
    body,
  ))
  json.parse(resp_body, exec_decoder())
  |> result.map_error(JsonDecodeError)
}

/// Exposes a VS Code server on the sandbox.
///
/// ## Example
///
/// ```gleam
/// sb |> sandbox.expose_vscode()
/// ```
pub fn expose_vscode(sb: ConnectedSandbox) -> Result(Nil, PocketenvError) {
  use _ <- result.try(do_post(
    sb.client,
    "/xrpc/io.pocketenv.sandbox.exposeVscode",
    [#("id", sb.data.id)],
    "{}",
  ))
  Ok(Nil)
}

/// JSON decoder for `Sandbox`.
pub fn sandbox_decoder() -> decode.Decoder(Sandbox) {
  use id <- decode.field("id", decode.string)
  use name <- decode.field("name", decode.string)
  use provider <- decode.optional_field(
    "provider",
    None,
    decode.optional(decode.string),
  )
  use base_sandbox <- decode.optional_field(
    "baseSandbox",
    None,
    decode.optional(decode.string),
  )
  use display_name <- decode.optional_field(
    "displayName",
    None,
    decode.optional(decode.string),
  )
  use uri <- decode.optional_field("uri", None, decode.optional(decode.string))
  use description <- decode.optional_field(
    "description",
    None,
    decode.optional(decode.string),
  )
  use topics <- decode.optional_field(
    "topics",
    None,
    decode.optional(decode.list(decode.string)),
  )
  use logo <- decode.optional_field(
    "logo",
    None,
    decode.optional(decode.string),
  )
  use readme <- decode.optional_field(
    "readme",
    None,
    decode.optional(decode.string),
  )
  use repo <- decode.optional_field(
    "repo",
    None,
    decode.optional(decode.string),
  )
  use vcpus <- decode.optional_field("vcpus", None, decode.optional(decode.int))
  use memory <- decode.optional_field(
    "memory",
    None,
    decode.optional(decode.int),
  )
  use disk <- decode.optional_field("disk", None, decode.optional(decode.int))
  use installs <- decode.optional_field(
    "installs",
    None,
    decode.optional(decode.int),
  )
  use status <- decode.optional_field(
    "status",
    None,
    decode.optional(decode.string),
  )
  use started_at <- decode.optional_field(
    "startedAt",
    None,
    decode.optional(decode.string),
  )
  use created_at <- decode.field("createdAt", decode.string)
  decode.success(Sandbox(
    id: id,
    name: name,
    provider: provider,
    base_sandbox: base_sandbox,
    display_name: display_name,
    uri: uri,
    description: description,
    topics: topics,
    logo: logo,
    readme: readme,
    repo: repo,
    vcpus: vcpus,
    memory: memory,
    disk: disk,
    installs: installs,
    status: status,
    started_at: started_at,
    created_at: created_at,
  ))
}

/// JSON decoder for `ExecResult`.
pub fn exec_decoder() -> decode.Decoder(ExecResult) {
  use stdout <- decode.field("stdout", decode.string)
  use stderr <- decode.field("stderr", decode.string)
  use exit_code <- decode.field("exitCode", decode.int)
  decode.success(ExecResult(
    stdout: stdout,
    stderr: stderr,
    exit_code: exit_code,
  ))
}
