# pocketenv

[![Package Version](https://img.shields.io/hexpm/v/pocketenv)](https://hex.pm/packages/pocketenv)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/pocketenv/)

A Gleam client library for the [Pocketenv](https://pocketenv.io) API, providing
access to sandboxes, environment variables, secrets, files, volumes, services,
ports, and networking.

```sh
gleam add pocketenv@1
```

## Usage

### Creating a client

```gleam
import pocketenv

pub fn main() {
  let client = pocketenv.new_client("your-api-token")
  // use client with any of the sub-modules below
}
```

### Sandboxes

```gleam
import pocketenv
import pocketenv/sandbox
import gleam/option.{None, Some}
import gleam/io

pub fn main() {
  let client = pocketenv.new_client("https://pocketenv.io", "your-token")

  let assert Ok(sb) =
    client
    |> sandbox.new("my-sandbox", "openclaw", "cloudflare")
    |> sandbox.with_description("My app sandbox")
    |> sandbox.create()
  io.println("Created: " <> sb.data.id)

  // List all sandboxes
  let assert Ok(#(sandboxes, _total)) = sandbox.list(client, None, None)
  io.debug(sandboxes)

  // Start, exec, then stop the sandbox
  let assert Ok(Nil) = sb |> sandbox.start(None, None)
  let assert Ok(result) = sb |> sandbox.exec("echo hello")
  io.println(result.stdout)
  let assert Ok(Nil) = sb |> sandbox.stop()

  // Delete when done
  let assert Ok(Nil) = sb |> sandbox.delete()
}
```

### Environment variables

```gleam
import pocketenv
import pocketenv/env
import gleam/option.{None}

pub fn main() {
  let client = pocketenv.new_client("https://pocketenv.io", "your-token")
  let sandbox_id = "sandbox-abc123"

  // Set a variable
  let assert Ok(Nil) = env.put(client, sandbox_id, "DATABASE_URL", "postgres://localhost/mydb")

  // List variables
  let assert Ok(vars) = env.list(client, sandbox_id, None, None)

  // Delete a variable by its id
  case vars {
    [first, ..] -> {
      let assert Ok(Nil) = env.delete(client, first.id)
    }
    [] -> Nil
  }
}
```

### Secrets

```gleam
import pocketenv
import pocketenv/secrets
import gleam/option.{None}

pub fn main() {
  let client = pocketenv.new_client("https://pocketenv.io", "your-token")
  let sandbox_id = "sandbox-abc123"

  // Store a secret
  let assert Ok(Nil) = secrets.put(client, sandbox_id, "API_KEY", "super-secret-value")

  // List secret names (values are never returned)
  let assert Ok(all) = secrets.list(client, sandbox_id, None, None)

  // Delete a secret
  case all {
    [first, ..] -> {
      let assert Ok(Nil) = secrets.delete(client, first.id)
    }
    [] -> Nil
  }
}
```

### Files

```gleam
import pocketenv
import pocketenv/files

pub fn main() {
  let client = pocketenv.new_client("https://pocketenv.io", "your-token")
  let sandbox_id = "sandbox-abc123"

  // Write a file into the sandbox
  let assert Ok(Nil) =
    files.write(client, sandbox_id, "/app/config.json", "{\"debug\": true}")

  // List files
  let assert Ok(all) = files.list(client, sandbox_id)

  // Delete a file
  case all {
    [first, ..] -> {
      let assert Ok(Nil) = files.delete(client, first.id)
    }
    [] -> Nil
  }
}
```

### Volumes

```gleam
import pocketenv
import pocketenv/volume

pub fn main() {
  let client = pocketenv.new_client("https://pocketenv.io", "your-token")
  let sandbox_id = "sandbox-abc123"

  // Mount a persistent volume
  let assert Ok(Nil) = volume.create(client, sandbox_id, "data-vol", "/mnt/data")

  // List volumes
  let assert Ok(vols) = volume.list(client, sandbox_id)

  // Delete a volume
  case vols {
    [first, ..] -> {
      let assert Ok(Nil) = volume.delete(client, first.id)
    }
    [] -> Nil
  }
}
```

### Services

```gleam
import pocketenv
import pocketenv/services
import gleam/option.{None, Some}

pub fn main() {
  let client = pocketenv.new_client("https://pocketenv.io", "your-token")
  let sandbox_id = "sandbox-abc123"

  // Register and start a web server service
  let assert Ok(Nil) =
    services.create(
      client,
      sandbox_id,
      "web",
      "python -m http.server 8080",
      Some([8080]),
      Some("Simple HTTP server"),
    )

  let assert Ok(svcs) = services.list(client, sandbox_id)
  case svcs {
    [svc, ..] -> {
      let assert Ok(Nil) = services.start(client, svc.id)
      let assert Ok(Nil) = services.restart(client, svc.id)
      let assert Ok(Nil) = services.stop(client, svc.id)
      let assert Ok(Nil) = services.delete(client, svc.id)
    }
    [] -> Nil
  }
}
```

### Ports & Networking

```gleam
import pocketenv
import pocketenv/network
import pocketenv/ports
import gleam/io
import gleam/option.{None, Some}

pub fn main() {
  let client = pocketenv.new_client("https://pocketenv.io", "your-token")
  let sandbox_id = "sandbox-abc123"

  // Expose a port and get a preview URL
  let assert Ok(preview_url) =
    network.expose(client, sandbox_id, 3000, Some("Dev server"))
  io.debug(preview_url)

  // List currently exposed ports
  let assert Ok(exposed) = ports.list(client, sandbox_id)
  io.debug(exposed)

  // Unexpose the port
  let assert Ok(Nil) = network.unexpose(client, sandbox_id, 3000)

  // Configure Tailscale networking
  let assert Ok(Nil) =
    network.setup_tailscale(client, sandbox_id, "tskey-auth-xxxx")
}
```

### Profile

```gleam
import pocketenv
import gleam/io

pub fn main() {
  let client = pocketenv.new_client("https://pocketenv.io", "your-token")
  let assert Ok(profile) = pocketenv.get_profile(client)
  io.println("Logged in as: " <> profile.handle)
}
```

## Error handling

All API functions return `Result(_, PocketenvError)`. The error variants are:

```gleam
import pocketenv.{ApiError, HttpError, JsonDecodeError, RequestBuildError}

case pocketenv.get_profile(client) {
  Ok(profile) -> io.println(profile.handle)
  Error(ApiError(status)) -> io.println("API error: " <> int.to_string(status))
  Error(HttpError(msg)) -> io.println("HTTP error: " <> msg)
  Error(JsonDecodeError(_)) -> io.println("Failed to decode response")
  Error(RequestBuildError) -> io.println("Could not build request URL")
}
```

Further documentation can be found at <https://hexdocs.pm/pocketenv>.

## Development

```sh
gleam run   # Run the project
gleam test  # Run the tests
```
