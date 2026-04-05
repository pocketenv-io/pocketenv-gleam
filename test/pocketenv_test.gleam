import gleam/bit_array
import gleam/int
import gleam/json
import gleam/option.{None, Some}
import gleeunit
import mock_server
import pocketenv
import pocketenv/copy
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

// ---- copy FFI helpers -------------------------------------------------------

@external(erlang, "pocketenv_copy_ffi", "random_hex")
fn random_hex(n: Int) -> String

@external(erlang, "pocketenv_copy_ffi", "write_file")
fn write_file(path: String, data: BitArray) -> Result(Nil, String)

@external(erlang, "pocketenv_copy_ffi", "compress")
fn compress(path: String) -> Result(String, String)

@external(erlang, "pocketenv_copy_ffi", "decompress")
fn decompress(archive: String, dest: String) -> Result(Nil, String)

@external(erlang, "pocketenv_copy_ffi", "file_exists")
fn file_exists(path: String) -> Bool

fn tmp_dir() -> String {
  "/tmp/pocketenv_test_" <> random_hex(8)
}

// ---- copy: compress / decompress roundtrip ----------------------------------

pub fn compress_decompress_single_file_test() {
  let dir = tmp_dir()
  let src = dir <> "/src/hello.txt"
  let assert Ok(Nil) = write_file(src, bit_array.from_string("hello world"))
  let assert Ok(archive) = compress(src)
  let dest = dir <> "/out"
  let assert Ok(Nil) = decompress(archive, dest)
  assert file_exists(dest <> "/hello.txt")
}

pub fn compress_decompress_directory_test() {
  let dir = tmp_dir()
  let assert Ok(Nil) =
    write_file(dir <> "/src/a.txt", bit_array.from_string("a"))
  let assert Ok(Nil) =
    write_file(dir <> "/src/sub/b.txt", bit_array.from_string("b"))
  let assert Ok(archive) = compress(dir <> "/src")
  let dest = dir <> "/out"
  let assert Ok(Nil) = decompress(archive, dest)
  assert file_exists(dest <> "/a.txt")
  assert file_exists(dest <> "/sub/b.txt")
}

// ---- copy: ignore file support ----------------------------------------------

pub fn compress_gitignore_excludes_files_test() {
  let dir = tmp_dir()
  let assert Ok(Nil) =
    write_file(dir <> "/src/keep.txt", bit_array.from_string("keep"))
  let assert Ok(Nil) =
    write_file(dir <> "/src/skip.log", bit_array.from_string("skip"))
  let assert Ok(Nil) =
    write_file(dir <> "/src/.gitignore", bit_array.from_string("*.log\n"))
  let assert Ok(archive) = compress(dir <> "/src")
  let dest = dir <> "/out"
  let assert Ok(Nil) = decompress(archive, dest)
  assert file_exists(dest <> "/keep.txt")
  assert !file_exists(dest <> "/skip.log")
}

pub fn compress_pocketenvignore_test() {
  let dir = tmp_dir()
  let assert Ok(Nil) =
    write_file(dir <> "/src/main.go", bit_array.from_string("package main"))
  let assert Ok(Nil) =
    write_file(dir <> "/src/build/output", bit_array.from_string("compiled"))
  let assert Ok(Nil) =
    write_file(
      dir <> "/src/.pocketenvignore",
      bit_array.from_string("build/\n"),
    )
  let assert Ok(archive) = compress(dir <> "/src")
  let dest = dir <> "/out"
  let assert Ok(Nil) = decompress(archive, dest)
  assert file_exists(dest <> "/main.go")
  assert !file_exists(dest <> "/build/output")
}

pub fn compress_negation_pattern_test() {
  let dir = tmp_dir()
  let assert Ok(Nil) =
    write_file(dir <> "/src/a.log", bit_array.from_string("a"))
  let assert Ok(Nil) =
    write_file(dir <> "/src/keep.log", bit_array.from_string("keep"))
  // Ignore all .log files, but re-include keep.log
  let assert Ok(Nil) =
    write_file(
      dir <> "/src/.gitignore",
      bit_array.from_string("*.log\n!keep.log\n"),
    )
  let assert Ok(archive) = compress(dir <> "/src")
  let dest = dir <> "/out"
  let assert Ok(Nil) = decompress(archive, dest)
  assert !file_exists(dest <> "/a.log")
  assert file_exists(dest <> "/keep.log")
}

// ---- copy: HTTP tests -------------------------------------------------------

fn stub_connected_with_storage(
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

pub fn copy_to_ok_test() {
  let #(port, pid) = mock_server.start()
  mock_server.set_response(
    "/xrpc/io.pocketenv.sandbox.pushDirectory",
    200,
    "{\"uuid\":\"test-uuid\"}",
  )
  mock_server.set_response(
    "/xrpc/io.pocketenv.sandbox.pullDirectory",
    200,
    "{}",
  )
  let client =
    pocketenv.new_client_with_urls(base_url(port), base_url(port), "tok")
  let result =
    stub_connected_with_storage("src-sb", client)
    |> copy.copy_to("dst-sb", "/src", "/dst")
  mock_server.stop(pid)
  assert result == Ok(Nil)
}

pub fn copy_to_push_error_test() {
  let #(port, pid) = mock_server.start()
  mock_server.set_response(
    "/xrpc/io.pocketenv.sandbox.pushDirectory",
    500,
    "{}",
  )
  let client =
    pocketenv.new_client_with_urls(base_url(port), base_url(port), "tok")
  let result =
    stub_connected_with_storage("sb", client)
    |> copy.copy_to("dst", "/a", "/b")
  mock_server.stop(pid)
  assert result == Error(pocketenv.ApiError(500))
}

pub fn copy_to_pull_error_test() {
  let #(port, pid) = mock_server.start()
  mock_server.set_response(
    "/xrpc/io.pocketenv.sandbox.pushDirectory",
    200,
    "{\"uuid\":\"u1\"}",
  )
  mock_server.set_response(
    "/xrpc/io.pocketenv.sandbox.pullDirectory",
    403,
    "{}",
  )
  let client =
    pocketenv.new_client_with_urls(base_url(port), base_url(port), "tok")
  let result =
    stub_connected_with_storage("sb", client)
    |> copy.copy_to("dst", "/a", "/b")
  mock_server.stop(pid)
  assert result == Error(pocketenv.ApiError(403))
}

pub fn download_push_error_test() {
  let #(port, pid) = mock_server.start()
  mock_server.set_response(
    "/xrpc/io.pocketenv.sandbox.pushDirectory",
    401,
    "{}",
  )
  let client =
    pocketenv.new_client_with_urls(base_url(port), base_url(port), "tok")
  let result =
    stub_connected_with_storage("sb", client)
    |> copy.download("/remote", tmp_dir())
  mock_server.stop(pid)
  assert result == Error(pocketenv.ApiError(401))
}

pub fn upload_pull_error_test() {
  let dir = tmp_dir()
  let src = dir <> "/src/file.txt"
  let assert Ok(Nil) = write_file(src, bit_array.from_string("content"))
  let #(port, pid) = mock_server.start()
  // Storage upload succeeds
  mock_server.set_response("/cp", 200, "{\"uuid\":\"u1\"}")
  // Pull fails
  mock_server.set_response(
    "/xrpc/io.pocketenv.sandbox.pullDirectory",
    500,
    "{}",
  )
  let client =
    pocketenv.new_client_with_urls(base_url(port), base_url(port), "tok")
  let result =
    stub_connected_with_storage("sb", client)
    |> copy.upload(src, "/remote")
  mock_server.stop(pid)
  assert result == Error(pocketenv.ApiError(500))
}
