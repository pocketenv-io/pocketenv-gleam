import gleam/dynamic.{type Dynamic}

@external(erlang, "mock_server_ffi", "start")
pub fn start() -> #(Int, Dynamic)

@external(erlang, "mock_server_ffi", "stop")
pub fn stop(pid: Dynamic) -> Nil

@external(erlang, "mock_server_ffi", "set_response")
pub fn set_response(path: String, status: Int, body: String) -> Nil
