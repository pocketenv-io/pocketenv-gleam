-module(mock_server_ffi).
-export([start/0, stop/1, set_response/3]).

start() ->
    case ets:whereis(mock_http_responses) of
        undefined -> ets:new(mock_http_responses, [named_table, public, set]);
        _         -> ets:delete_all_objects(mock_http_responses)
    end,
    Self = self(),
    Pid = spawn(fun() ->
        {ok, LSock} = gen_tcp:listen(0, [binary, {packet, raw}, {active, false}, {reuseaddr, true}]),
        {ok, Port} = inet:port(LSock),
        Self ! {ready, Port},
        accept_loop(LSock)
    end),
    receive {ready, Port} -> {Port, Pid} end.

stop(Pid) ->
    exit(Pid, kill).

set_response(Path, Status, Body) ->
    ets:insert(mock_http_responses, {
        unicode:characters_to_list(Path),
        Status,
        unicode:characters_to_list(Body)
    }).

accept_loop(LSock) ->
    case gen_tcp:accept(LSock, 5000) of
        {ok, CSock} ->
            spawn(fun() -> handle(CSock) end),
            accept_loop(LSock);
        _ ->
            ok
    end.

handle(Sock) ->
    case recv_request_line(Sock, <<>>) of
        {ok, RequestLine} ->
            Parts = string:split(RequestLine, " ", all),
            Path = case Parts of
                [_, P | _] ->
                    [Base | _] = string:split(P, "?"),
                    Base;
                _ ->
                    "/"
            end,
            {Status, RespBody} = case ets:lookup(mock_http_responses, Path) of
                [{_, S, B}] -> {S, B};
                []          -> {200, "{}"}
            end,
            Resp = io_lib:format(
                "HTTP/1.1 ~w OK\r\nContent-Type: application/json\r\nContent-Length: ~w\r\nConnection: close\r\n\r\n~s",
                [Status, length(RespBody), RespBody]
            ),
            gen_tcp:send(Sock, Resp);
        _ ->
            ok
    end,
    gen_tcp:close(Sock).

recv_request_line(Sock, Acc) ->
    case gen_tcp:recv(Sock, 0, 5000) of
        {ok, Data} ->
            Full = <<Acc/binary, Data/binary>>,
            case binary:match(Full, <<"\r\n">>) of
                {Pos, _} ->
                    Line = binary:part(Full, 0, Pos),
                    {ok, binary_to_list(Line)};
                nomatch ->
                    recv_request_line(Sock, Full)
            end;
        {error, Reason} ->
            {error, Reason}
    end.
