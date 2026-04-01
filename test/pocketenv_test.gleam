import gleam/int
import gleam/json
import gleam/option.{None, Some}
import gleeunit
import mock_server
import pocketenv
import pocketenv/env
import pocketenv/files
import pocketenv/ports
import pocketenv/sandbox
import pocketenv/secrets
import pocketenv/services
import pocketenv/volume

pub fn main() -> Nil {
  gleeunit.main()
}

// ---- profile ----------------------------------------------------------------

pub fn profile_decoder_full_test() {
  let json_str =
    "{\"id\":\"abc\",\"did\":\"did:plc:123\",\"handle\":\"alice.bsky.social\",\"displayName\":\"Alice\",\"avatar\":\"https://example.com/avatar.jpg\",\"createdAt\":\"2024-01-01\",\"updatedAt\":\"2024-06-01\"}"
  let result = json.parse(json_str, pocketenv.profile_decoder())
  assert result
    == Ok(pocketenv.Profile(
      id: Some("abc"),
      did: "did:plc:123",
      handle: "alice.bsky.social",
      display_name: Some("Alice"),
      avatar: Some("https://example.com/avatar.jpg"),
      created_at: Some("2024-01-01"),
      updated_at: Some("2024-06-01"),
    ))
}

pub fn profile_decoder_minimal_test() {
  let json_str = "{\"did\":\"did:plc:456\",\"handle\":\"bob.bsky.social\"}"
  let result = json.parse(json_str, pocketenv.profile_decoder())
  assert result
    == Ok(pocketenv.Profile(
      id: None,
      did: "did:plc:456",
      handle: "bob.bsky.social",
      display_name: None,
      avatar: None,
      created_at: None,
      updated_at: None,
    ))
}

pub fn profile_decoder_missing_required_field_test() {
  let json_str = "{\"did\":\"did:plc:789\"}"
  let result = json.parse(json_str, pocketenv.profile_decoder())
  assert result |> is_error
}

// ---- sandbox ----------------------------------------------------------------

pub fn sandbox_decoder_full_test() {
  let json_str =
    "{\"id\":\"s1\",\"name\":\"my-sandbox\",\"provider\":\"cloudflare\",\"baseSandbox\":\"base\",\"displayName\":\"My Sandbox\",\"uri\":\"https://sandbox.example.com\",\"description\":\"A test sandbox\",\"topics\":[\"gleam\",\"elixir\"],\"logo\":\"https://example.com/logo.png\",\"readme\":\"# Hello\",\"repo\":\"https://github.com/example/repo\",\"vcpus\":2,\"memory\":512,\"disk\":10,\"installs\":5,\"status\":\"running\",\"startedAt\":\"2024-01-02\",\"createdAt\":\"2024-01-01\"}"
  let result = json.parse(json_str, sandbox.sandbox_decoder())
  assert result
    == Ok(sandbox.Sandbox(
      id: "s1",
      name: "my-sandbox",
      provider: Some("cloudflare"),
      base_sandbox: Some("base"),
      display_name: Some("My Sandbox"),
      uri: Some("https://sandbox.example.com"),
      description: Some("A test sandbox"),
      topics: Some(["gleam", "elixir"]),
      logo: Some("https://example.com/logo.png"),
      readme: Some("# Hello"),
      repo: Some("https://github.com/example/repo"),
      vcpus: Some(2),
      memory: Some(512),
      disk: Some(10),
      installs: Some(5),
      status: Some("running"),
      started_at: Some("2024-01-02"),
      created_at: "2024-01-01",
    ))
}

pub fn sandbox_decoder_minimal_test() {
  let json_str =
    "{\"id\":\"s2\",\"name\":\"bare\",\"createdAt\":\"2024-03-01\"}"
  let result = json.parse(json_str, sandbox.sandbox_decoder())
  assert result
    == Ok(sandbox.Sandbox(
      id: "s2",
      name: "bare",
      provider: None,
      base_sandbox: None,
      display_name: None,
      uri: None,
      description: None,
      topics: None,
      logo: None,
      readme: None,
      repo: None,
      vcpus: None,
      memory: None,
      disk: None,
      installs: None,
      status: None,
      started_at: None,
      created_at: "2024-03-01",
    ))
}

pub fn sandbox_decoder_missing_required_test() {
  let json_str = "{\"name\":\"no-id\",\"createdAt\":\"2024-03-01\"}"
  let result = json.parse(json_str, sandbox.sandbox_decoder())
  assert result |> is_error
}

pub fn exec_decoder_test() {
  let json_str = "{\"stdout\":\"hello\\n\",\"stderr\":\"\",\"exitCode\":0}"
  let result = json.parse(json_str, sandbox.exec_decoder())
  assert result
    == Ok(sandbox.ExecResult(stdout: "hello\n", stderr: "", exit_code: 0))
}

pub fn exec_decoder_nonzero_exit_test() {
  let json_str =
    "{\"stdout\":\"\",\"stderr\":\"error: command not found\",\"exitCode\":127}"
  let result = json.parse(json_str, sandbox.exec_decoder())
  assert result
    == Ok(sandbox.ExecResult(
      stdout: "",
      stderr: "error: command not found",
      exit_code: 127,
    ))
}

// ---- env (variables) --------------------------------------------------------

pub fn variable_decoder_test() {
  let json_str =
    "{\"id\":\"v1\",\"name\":\"DATABASE_URL\",\"value\":\"postgres://localhost/db\",\"createdAt\":\"2024-02-01\"}"
  let result = json.parse(json_str, env.variable_decoder())
  assert result
    == Ok(env.Variable(
      id: "v1",
      name: "DATABASE_URL",
      value: "postgres://localhost/db",
      created_at: "2024-02-01",
    ))
}

pub fn variable_decoder_missing_field_test() {
  let json_str =
    "{\"id\":\"v2\",\"name\":\"MISSING_VALUE\",\"createdAt\":\"2024-02-01\"}"
  let result = json.parse(json_str, env.variable_decoder())
  assert result |> is_error
}

// ---- files ------------------------------------------------------------------

pub fn file_decoder_test() {
  let json_str =
    "{\"id\":\"f1\",\"path\":\"/etc/config.yaml\",\"createdAt\":\"2024-04-01\"}"
  let result = json.parse(json_str, files.file_decoder())
  assert result
    == Ok(files.File(
      id: "f1",
      path: "/etc/config.yaml",
      created_at: "2024-04-01",
    ))
}

pub fn file_decoder_missing_path_test() {
  let json_str = "{\"id\":\"f2\",\"createdAt\":\"2024-04-01\"}"
  let result = json.parse(json_str, files.file_decoder())
  assert result |> is_error
}

// ---- ports ------------------------------------------------------------------

pub fn port_decoder_full_test() {
  let json_str =
    "{\"port\":8080,\"description\":\"HTTP\",\"previewUrl\":\"https://preview.example.com\"}"
  let result = json.parse(json_str, ports.port_decoder())
  assert result
    == Ok(ports.Port(
      port: 8080,
      description: Some("HTTP"),
      preview_url: Some("https://preview.example.com"),
    ))
}

pub fn port_decoder_minimal_test() {
  let json_str = "{\"port\":3000}"
  let result = json.parse(json_str, ports.port_decoder())
  assert result
    == Ok(ports.Port(port: 3000, description: None, preview_url: None))
}

pub fn port_decoder_missing_port_test() {
  let json_str = "{\"description\":\"no port\"}"
  let result = json.parse(json_str, ports.port_decoder())
  assert result |> is_error
}

// ---- services ---------------------------------------------------------------

pub fn service_decoder_full_test() {
  let json_str =
    "{\"id\":\"svc1\",\"name\":\"web\",\"command\":\"npm start\",\"ports\":[3000,8080],\"description\":\"Web server\",\"status\":\"running\",\"createdAt\":\"2024-05-01\"}"
  let result = json.parse(json_str, services.service_decoder())
  assert result
    == Ok(services.Service(
      id: "svc1",
      name: "web",
      command: "npm start",
      ports: Some([3000, 8080]),
      description: Some("Web server"),
      status: "running",
      created_at: "2024-05-01",
    ))
}

pub fn service_decoder_minimal_test() {
  let json_str =
    "{\"id\":\"svc2\",\"name\":\"worker\",\"command\":\"./run.sh\",\"status\":\"stopped\",\"createdAt\":\"2024-05-02\"}"
  let result = json.parse(json_str, services.service_decoder())
  assert result
    == Ok(services.Service(
      id: "svc2",
      name: "worker",
      command: "./run.sh",
      ports: None,
      description: None,
      status: "stopped",
      created_at: "2024-05-02",
    ))
}

// ---- volume -----------------------------------------------------------------

pub fn volume_decoder_test() {
  let json_str =
    "{\"id\":\"vol1\",\"name\":\"data\",\"path\":\"/mnt/data\",\"createdAt\":\"2024-06-01\"}"
  let result = json.parse(json_str, volume.volume_decoder())
  assert result
    == Ok(volume.Volume(
      id: "vol1",
      name: "data",
      path: "/mnt/data",
      created_at: "2024-06-01",
    ))
}

pub fn volume_decoder_missing_path_test() {
  let json_str =
    "{\"id\":\"vol2\",\"name\":\"tmp\",\"createdAt\":\"2024-06-02\"}"
  let result = json.parse(json_str, volume.volume_decoder())
  assert result |> is_error
}

// ---- secrets ----------------------------------------------------------------

pub fn secret_decoder_test() {
  let json_str =
    "{\"id\":\"sec1\",\"name\":\"API_KEY\",\"createdAt\":\"2024-07-01\"}"
  let result = json.parse(json_str, secrets.secret_decoder())
  assert result
    == Ok(secrets.Secret(id: "sec1", name: "API_KEY", created_at: "2024-07-01"))
}

pub fn secret_decoder_missing_name_test() {
  let json_str = "{\"id\":\"sec2\",\"createdAt\":\"2024-07-02\"}"
  let result = json.parse(json_str, secrets.secret_decoder())
  assert result |> is_error
}

// ---- helpers ----------------------------------------------------------------

fn is_error(result: Result(a, b)) -> Bool {
  case result {
    Ok(_) -> False
    Error(_) -> True
  }
}

fn base_url(port: Int) -> String {
  "http://localhost:" <> int.to_string(port)
}

// ---- sandbox HTTP -----------------------------------------------------------

pub fn sandbox_create_ok_test() {
  let resp =
    "{\"id\":\"s1\",\"name\":\"my-box\",\"provider\":\"cloudflare\",\"createdAt\":\"2024-01-01\"}"
  let #(port, pid) = mock_server.start()
  mock_server.set_response(
    "/xrpc/io.pocketenv.sandbox.createSandbox",
    200,
    resp,
  )
  let client = pocketenv.new_client_with_base_url(base_url(port), "tok")
  let assert Ok(sb) =
    client
    |> sandbox.new("my-box", "base", "cloudflare")
    |> sandbox.create()
  mock_server.stop(pid)
  assert sb.data
    == sandbox.Sandbox(
      id: "s1",
      name: "my-box",
      provider: Some("cloudflare"),
      base_sandbox: None,
      display_name: None,
      uri: None,
      description: None,
      topics: None,
      logo: None,
      readme: None,
      repo: None,
      vcpus: None,
      memory: None,
      disk: None,
      installs: None,
      status: None,
      started_at: None,
      created_at: "2024-01-01",
    )
}

pub fn sandbox_create_api_error_test() {
  let #(port, pid) = mock_server.start()
  mock_server.set_response(
    "/xrpc/io.pocketenv.sandbox.createSandbox",
    401,
    "{\"error\":\"Unauthorized\"}",
  )
  let client = pocketenv.new_client_with_base_url(base_url(port), "bad-token")
  let result =
    client
    |> sandbox.new("x", "base", "cloudflare")
    |> sandbox.create()
  mock_server.stop(pid)
  assert result == Error(pocketenv.ApiError(401))
}

pub fn sandbox_create_invalid_json_test() {
  let #(port, pid) = mock_server.start()
  mock_server.set_response(
    "/xrpc/io.pocketenv.sandbox.createSandbox",
    200,
    "not-json",
  )
  let client = pocketenv.new_client_with_base_url(base_url(port), "tok")
  let result =
    client
    |> sandbox.new("x", "base", "cloudflare")
    |> sandbox.create()
  mock_server.stop(pid)
  assert result |> is_error
}

fn stub_connected(
  id: String,
  client: pocketenv.Client,
) -> sandbox.ConnectedSandbox {
  sandbox.connect(
    sandbox.Sandbox(
      id: id,
      name: "stub",
      provider: None,
      base_sandbox: None,
      display_name: None,
      uri: None,
      description: None,
      topics: None,
      logo: None,
      readme: None,
      repo: None,
      vcpus: None,
      memory: None,
      disk: None,
      installs: None,
      status: None,
      started_at: None,
      created_at: "2024-01-01",
    ),
    client,
  )
}

pub fn sandbox_start_ok_test() {
  let #(port, pid) = mock_server.start()
  mock_server.set_response("/xrpc/io.pocketenv.sandbox.startSandbox", 200, "{}")
  let client = pocketenv.new_client_with_base_url(base_url(port), "tok")
  let result = stub_connected("s1", client) |> sandbox.start(None, None)
  mock_server.stop(pid)
  assert result == Ok(Nil)
}

pub fn sandbox_start_error_test() {
  let #(port, pid) = mock_server.start()
  mock_server.set_response("/xrpc/io.pocketenv.sandbox.startSandbox", 500, "{}")
  let client = pocketenv.new_client_with_base_url(base_url(port), "tok")
  let result = stub_connected("s1", client) |> sandbox.start(None, None)
  mock_server.stop(pid)
  assert result == Error(pocketenv.ApiError(500))
}

pub fn sandbox_stop_ok_test() {
  let #(port, pid) = mock_server.start()
  mock_server.set_response("/xrpc/io.pocketenv.sandbox.stopSandbox", 200, "{}")
  let client = pocketenv.new_client_with_base_url(base_url(port), "tok")
  let result = stub_connected("s1", client) |> sandbox.stop()
  mock_server.stop(pid)
  assert result == Ok(Nil)
}

pub fn sandbox_stop_error_test() {
  let #(port, pid) = mock_server.start()
  mock_server.set_response("/xrpc/io.pocketenv.sandbox.stopSandbox", 404, "{}")
  let client = pocketenv.new_client_with_base_url(base_url(port), "tok")
  let result = stub_connected("missing", client) |> sandbox.stop()
  mock_server.stop(pid)
  assert result == Error(pocketenv.ApiError(404))
}

pub fn sandbox_exec_ok_test() {
  let resp = "{\"stdout\":\"hello\\n\",\"stderr\":\"\",\"exitCode\":0}"
  let #(port, pid) = mock_server.start()
  mock_server.set_response("/xrpc/io.pocketenv.sandbox.exec", 200, resp)
  let client = pocketenv.new_client_with_base_url(base_url(port), "tok")
  let result = stub_connected("s1", client) |> sandbox.exec("echo hello")
  mock_server.stop(pid)
  assert result
    == Ok(sandbox.ExecResult(stdout: "hello\n", stderr: "", exit_code: 0))
}

pub fn sandbox_exec_nonzero_exit_test() {
  let resp = "{\"stdout\":\"\",\"stderr\":\"not found\",\"exitCode\":127}"
  let #(port, pid) = mock_server.start()
  mock_server.set_response("/xrpc/io.pocketenv.sandbox.exec", 200, resp)
  let client = pocketenv.new_client_with_base_url(base_url(port), "tok")
  let result = stub_connected("s1", client) |> sandbox.exec("badcmd")
  mock_server.stop(pid)
  assert result
    == Ok(sandbox.ExecResult(stdout: "", stderr: "not found", exit_code: 127))
}

pub fn sandbox_exec_api_error_test() {
  let #(port, pid) = mock_server.start()
  mock_server.set_response("/xrpc/io.pocketenv.sandbox.exec", 403, "{}")
  let client = pocketenv.new_client_with_base_url(base_url(port), "tok")
  let result = stub_connected("s1", client) |> sandbox.exec("ls")
  mock_server.stop(pid)
  assert result == Error(pocketenv.ApiError(403))
}
