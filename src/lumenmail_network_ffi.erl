%% Minimal FFI for Erlang gen_tcp and ssl modules.
%% This module provides thin wrappers around Erlang's networking functions.
-module(lumenmail_network_ffi).

-export([
    tcp_connect/4,
    ssl_connect/4,
    ensure_ssl_started/0,
    send/3,
    recv/3,
    close/2
]).

%% @doc Establish a TCP connection.
tcp_connect(Host, Port, _Options, Timeout) ->
    HostStr = binary_to_list(Host),
    Options = [binary, {active, false}, {packet, line}, {reuseaddr, true}],
    case gen_tcp:connect(HostStr, Port, Options, Timeout) of
        {ok, Socket} -> {ok, Socket};
        {error, Reason} -> {error, format_reason(Reason)}
    end.

%% @doc Upgrade TCP socket to SSL/TLS.
ssl_connect(Socket, Host, AllowInvalidCerts, Timeout) ->
    HostStr = binary_to_list(Host),
    BaseOptions = [binary, {active, false}, {packet, line}],
    Options = case AllowInvalidCerts of
        true ->
            [{verify, verify_none} | BaseOptions];
        false ->
            [{verify, verify_peer},
             {server_name_indication, HostStr},
             {cacerts, public_key:cacerts_get()}
             | BaseOptions]
    end,
    case ssl:connect(Socket, Options, Timeout) of
        {ok, SslSocket} -> {ok, SslSocket};
        {error, Reason} -> {error, format_reason(Reason)}
    end.

%% @doc Ensure SSL application is started.
ensure_ssl_started() ->
    application:ensure_all_started(ssl),
    nil.

%% @doc Send data over socket.
send(Socket, IsTls, Data) ->
    Result = case IsTls of
        true -> ssl:send(Socket, Data);
        false -> gen_tcp:send(Socket, Data)
    end,
    case Result of
        ok -> {ok, nil};
        {error, Reason} -> {error, format_reason(Reason)}
    end.

%% @doc Receive a line from socket.
recv(Socket, IsTls, Timeout) ->
    Result = case IsTls of
        true -> ssl:recv(Socket, 0, Timeout);
        false -> gen_tcp:recv(Socket, 0, Timeout)
    end,
    case Result of
        {ok, Data} -> {ok, Data};
        {error, closed} -> {error, <<"closed">>};
        {error, timeout} -> {error, <<"timeout">>};
        {error, Reason} -> {error, format_reason(Reason)}
    end.

%% @doc Close socket.
close(Socket, IsTls) ->
    case IsTls of
        true -> ssl:close(Socket);
        false -> gen_tcp:close(Socket)
    end,
    nil.

%% Internal: format error reason to binary string.
format_reason(Reason) when is_atom(Reason) ->
    atom_to_binary(Reason, utf8);
format_reason(Reason) when is_list(Reason) ->
    list_to_binary(Reason);
format_reason(Reason) when is_binary(Reason) ->
    Reason;
format_reason(Reason) ->
    iolist_to_binary(io_lib:format("~p", [Reason])).
