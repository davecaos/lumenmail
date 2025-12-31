//// SMTP client implementation.
//// Provides functionality for connecting to SMTP servers and sending emails.

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import lumenmail/auth
import lumenmail/message.{type Message}
import lumenmail/network
import lumenmail/types.{
  type Credentials, type ServerCapabilities, type SmtpResponse, type SmtpResult,
  type TlsMode, AuthCramMd5, AuthLogin, AuthPlain, AuthXOAuth2,
  AuthenticationFailed, CommandRejected, ImplicitTls, StartTls,
}

/// SMTP client configuration builder.
pub type SmtpClientBuilder {
  SmtpClientBuilder(
    host: String,
    port: Int,
    tls_mode: TlsMode,
    credentials: Option(Credentials),
    timeout_ms: Int,
    helo_host: String,
    allow_invalid_certs: Bool,
  )
}

/// Active SMTP connection.
pub type SmtpClient {
  SmtpClient(socket: network.Socket, capabilities: ServerCapabilities, is_tls: Bool)
}

/// Socket type - re-exported from network module.
pub type Socket =
  network.Socket

/// Creates a new SMTP client builder.
pub fn builder(host: String, port: Int) -> SmtpClientBuilder {
  let tls_mode = case port {
    465 -> ImplicitTls
    _ -> StartTls
  }

  SmtpClientBuilder(
    host: host,
    port: port,
    tls_mode: tls_mode,
    credentials: None,
    timeout_ms: 30_000,
    helo_host: "localhost",
    allow_invalid_certs: False,
  )
}

/// Sets the TLS mode.
pub fn tls_mode(builder: SmtpClientBuilder, mode: TlsMode) -> SmtpClientBuilder {
  SmtpClientBuilder(..builder, tls_mode: mode)
}

/// Sets implicit TLS mode (port 465).
pub fn implicit_tls(
  builder: SmtpClientBuilder,
  use_implicit: Bool,
) -> SmtpClientBuilder {
  case use_implicit {
    True -> SmtpClientBuilder(..builder, tls_mode: ImplicitTls)
    False -> SmtpClientBuilder(..builder, tls_mode: StartTls)
  }
}

/// Sets authentication credentials.
pub fn credentials(
  builder: SmtpClientBuilder,
  creds: Credentials,
) -> SmtpClientBuilder {
  SmtpClientBuilder(..builder, credentials: Some(creds))
}

/// Sets username/password credentials.
pub fn auth(
  builder: SmtpClientBuilder,
  username: String,
  password: String,
) -> SmtpClientBuilder {
  SmtpClientBuilder(
    ..builder,
    credentials: Some(types.Plain(username, password)),
  )
}

/// Sets connection timeout in milliseconds.
pub fn timeout(builder: SmtpClientBuilder, timeout_ms: Int) -> SmtpClientBuilder {
  SmtpClientBuilder(..builder, timeout_ms: timeout_ms)
}

/// Sets the hostname used in HELO/EHLO.
pub fn helo_host(builder: SmtpClientBuilder, host: String) -> SmtpClientBuilder {
  SmtpClientBuilder(..builder, helo_host: host)
}

/// Allow invalid/self-signed TLS certificates.
pub fn allow_invalid_certs(
  builder: SmtpClientBuilder,
  allow: Bool,
) -> SmtpClientBuilder {
  SmtpClientBuilder(..builder, allow_invalid_certs: allow)
}

/// Connects to the SMTP server.
pub fn connect(builder: SmtpClientBuilder) -> SmtpResult(SmtpClient) {
  // Establish TCP connection
  use socket <- result.try(tcp_connect(
    builder.host,
    builder.port,
    builder.timeout_ms,
  ))

  // For implicit TLS, upgrade connection immediately
  use #(socket, is_tls) <- result.try(case builder.tls_mode {
    ImplicitTls -> {
      use tls_socket <- result.try(ssl_connect(
        socket,
        builder.host,
        builder.allow_invalid_certs,
        builder.timeout_ms,
      ))
      Ok(#(tls_socket, True))
    }
    _ -> Ok(#(socket, False))
  })

  // Read server greeting
  use response <- result.try(read_response(socket, is_tls, builder.timeout_ms))
  use _ <- result.try(check_response_code(response, 220))

  // Send EHLO and get capabilities
  use capabilities <- result.try(send_ehlo(
    socket,
    is_tls,
    builder.helo_host,
    builder.timeout_ms,
  ))

  // Upgrade to TLS via STARTTLS if needed
  use #(socket, is_tls, capabilities) <- result.try(case
    builder.tls_mode,
    is_tls,
    capabilities.starttls
  {
    StartTls, False, True -> {
      // Send STARTTLS command
      use _ <- result.try(send_command(
        socket,
        is_tls,
        "STARTTLS",
        builder.timeout_ms,
      ))
      use response <- result.try(read_response(
        socket,
        is_tls,
        builder.timeout_ms,
      ))
      use _ <- result.try(check_response_code(response, 220))

      // Upgrade to TLS
      use tls_socket <- result.try(ssl_connect(
        socket,
        builder.host,
        builder.allow_invalid_certs,
        builder.timeout_ms,
      ))

      // Re-send EHLO after TLS upgrade
      use new_caps <- result.try(send_ehlo(
        tls_socket,
        True,
        builder.helo_host,
        builder.timeout_ms,
      ))
      Ok(#(tls_socket, True, new_caps))
    }
    _, _, _ -> Ok(#(socket, is_tls, capabilities))
  })

  // Authenticate if credentials provided
  use _ <- result.try(case builder.credentials {
    Some(creds) ->
      authenticate(socket, is_tls, creds, capabilities, builder.timeout_ms)
    None -> Ok(Nil)
  })

  Ok(SmtpClient(socket: socket, capabilities: capabilities, is_tls: is_tls))
}

/// Sends an email message.
pub fn send(client: SmtpClient, msg: Message) -> SmtpResult(Nil) {
  // Build the message
  use message_str <- result.try(
    msg
    |> message.build
    |> result.map_error(fn(e) { types.MessageRejected(e) }),
  )

  // Get sender
  use from <- result.try(case msg.from {
    Some(addr) -> Ok(addr.email)
    None -> Error(types.MessageRejected("No sender address"))
  })

  // Get recipients
  let recipients = message.all_recipients(msg)
  use _ <- result.try(case recipients {
    [] -> Error(types.MessageRejected("No recipients"))
    _ -> Ok(Nil)
  })

  // MAIL FROM
  use _ <- result.try(send_command(
    client.socket,
    client.is_tls,
    "MAIL FROM:<" <> from <> ">",
    30_000,
  ))
  use response <- result.try(read_response(client.socket, client.is_tls, 30_000))
  use _ <- result.try(check_response_code(response, 250))

  // RCPT TO for each recipient
  use _ <- result.try(
    list.try_each(recipients, fn(addr) {
      use _ <- result.try(send_command(
        client.socket,
        client.is_tls,
        "RCPT TO:<" <> addr.email <> ">",
        30_000,
      ))
      use response <- result.try(read_response(
        client.socket,
        client.is_tls,
        30_000,
      ))
      check_response_code_250_251(response)
    }),
  )

  // DATA
  use _ <- result.try(send_command(
    client.socket,
    client.is_tls,
    "DATA",
    30_000,
  ))
  use response <- result.try(read_response(client.socket, client.is_tls, 30_000))
  use _ <- result.try(check_response_code(response, 354))

  // Send message body
  use _ <- result.try(send_data(
    client.socket,
    client.is_tls,
    message_str,
    30_000,
  ))

  // End with <CRLF>.<CRLF>
  use _ <- result.try(send_command(client.socket, client.is_tls, ".", 60_000))
  use response <- result.try(read_response(client.socket, client.is_tls, 60_000))
  use _ <- result.try(check_response_code(response, 250))

  Ok(Nil)
}

/// Sends a raw email with pre-built content.
pub fn send_raw(
  client: SmtpClient,
  from: String,
  to: List(String),
  data: String,
) -> SmtpResult(Nil) {
  // MAIL FROM
  use _ <- result.try(send_command(
    client.socket,
    client.is_tls,
    "MAIL FROM:<" <> from <> ">",
    30_000,
  ))
  use response <- result.try(read_response(client.socket, client.is_tls, 30_000))
  use _ <- result.try(check_response_code(response, 250))

  // RCPT TO for each recipient
  use _ <- result.try(
    list.try_each(to, fn(addr) {
      use _ <- result.try(send_command(
        client.socket,
        client.is_tls,
        "RCPT TO:<" <> addr <> ">",
        30_000,
      ))
      use response <- result.try(read_response(
        client.socket,
        client.is_tls,
        30_000,
      ))
      check_response_code_250_251(response)
    }),
  )

  // DATA
  use _ <- result.try(send_command(
    client.socket,
    client.is_tls,
    "DATA",
    30_000,
  ))
  use response <- result.try(read_response(client.socket, client.is_tls, 30_000))
  use _ <- result.try(check_response_code(response, 354))

  // Send message body
  use _ <- result.try(send_data(client.socket, client.is_tls, data, 30_000))

  // End with <CRLF>.<CRLF>
  use _ <- result.try(send_command(client.socket, client.is_tls, ".", 60_000))
  use response <- result.try(read_response(client.socket, client.is_tls, 60_000))
  use _ <- result.try(check_response_code(response, 250))

  Ok(Nil)
}

/// Closes the SMTP connection gracefully.
pub fn close(client: SmtpClient) -> SmtpResult(Nil) {
  // Send QUIT command
  let _ =
    send_command(client.socket, client.is_tls, "QUIT", 5000)
    |> result.try(fn(_) { read_response(client.socket, client.is_tls, 5000) })

  // Close socket
  close_socket(client.socket, client.is_tls)
  Ok(Nil)
}

/// Resets the connection state (for sending multiple emails).
pub fn reset(client: SmtpClient) -> SmtpResult(Nil) {
  use _ <- result.try(send_command(
    client.socket,
    client.is_tls,
    "RSET",
    30_000,
  ))
  use response <- result.try(read_response(client.socket, client.is_tls, 30_000))
  check_response_code(response, 250)
}

/// Sends a NOOP command to keep connection alive.
pub fn noop(client: SmtpClient) -> SmtpResult(Nil) {
  use _ <- result.try(send_command(
    client.socket,
    client.is_tls,
    "NOOP",
    30_000,
  ))
  use response <- result.try(read_response(client.socket, client.is_tls, 30_000))
  check_response_code(response, 250)
}

/// Gets server capabilities.
pub fn capabilities(client: SmtpClient) -> ServerCapabilities {
  client.capabilities
}

// Internal helper functions

fn send_ehlo(
  socket: Socket,
  is_tls: Bool,
  helo_host: String,
  timeout: Int,
) -> SmtpResult(ServerCapabilities) {
  use _ <- result.try(send_command(
    socket,
    is_tls,
    "EHLO " <> helo_host,
    timeout,
  ))
  use response <- result.try(read_multiline_response(socket, is_tls, timeout))

  case response.code >= 200 && response.code < 300 {
    True -> Ok(parse_capabilities(response.message))
    False ->
      // Fallback to HELO
      {
        use _ <- result.try(send_command(
          socket,
          is_tls,
          "HELO " <> helo_host,
          timeout,
        ))
        use response <- result.try(read_response(socket, is_tls, timeout))
        case response.code >= 200 && response.code < 300 {
          True -> Ok(types.empty_capabilities())
          False ->
            Error(CommandRejected(
              response.code,
              "HELO failed: " <> response.message,
            ))
        }
      }
  }
}

fn parse_capabilities(ehlo_response: String) -> ServerCapabilities {
  let lines = string.split(ehlo_response, "\n")
  let caps = types.empty_capabilities()

  list.fold(lines, caps, fn(caps, line) {
    let line = string.trim(line)
    let upper = string.uppercase(line)

    case string.starts_with(upper, "STARTTLS") {
      True -> types.ServerCapabilities(..caps, starttls: True)
      False ->
        case string.starts_with(upper, "AUTH ") {
          True -> {
            let mechs =
              string.drop_start(upper, 5)
              |> string.split(" ")
              |> list.filter_map(auth.parse_mechanism)
            types.ServerCapabilities(..caps, auth_mechanisms: mechs)
          }
          False ->
            case string.starts_with(upper, "8BITMIME") {
              True -> types.ServerCapabilities(..caps, eight_bit_mime: True)
              False ->
                case string.starts_with(upper, "PIPELINING") {
                  True -> types.ServerCapabilities(..caps, pipelining: True)
                  False ->
                    case string.starts_with(upper, "SIZE") {
                      True -> {
                        let size =
                          string.drop_start(upper, 5)
                          |> string.trim
                          |> int.parse
                          |> result.unwrap(0)
                        types.ServerCapabilities(..caps, size: size)
                      }
                      False ->
                        case string.starts_with(upper, "DSN") {
                          True -> types.ServerCapabilities(..caps, dsn: True)
                          False -> caps
                        }
                    }
                }
            }
        }
    }
  })
  |> fn(c) {
    types.ServerCapabilities(
      ..c,
      extensions: list.map(lines, string.trim)
        |> list.filter(fn(l) { l != "" }),
    )
  }
}

fn authenticate(
  socket: Socket,
  is_tls: Bool,
  creds: Credentials,
  caps: ServerCapabilities,
  timeout: Int,
) -> SmtpResult(Nil) {
  // Select best mechanism
  use mechanism <- result.try(
    auth.select_best_mechanism(caps.auth_mechanisms, creds)
    |> result.map_error(AuthenticationFailed),
  )

  case mechanism {
    AuthPlain -> auth_plain(socket, is_tls, creds, timeout)
    AuthLogin -> auth_login(socket, is_tls, creds, timeout)
    AuthCramMd5 -> auth_cram_md5(socket, is_tls, creds, timeout)
    AuthXOAuth2 -> auth_xoauth2(socket, is_tls, creds, timeout)
  }
}

fn auth_plain(
  socket: Socket,
  is_tls: Bool,
  creds: Credentials,
  timeout: Int,
) -> SmtpResult(Nil) {
  let encoded = auth.encode_plain(creds)
  use _ <- result.try(send_command(
    socket,
    is_tls,
    "AUTH PLAIN " <> encoded,
    timeout,
  ))
  use response <- result.try(read_response(socket, is_tls, timeout))
  case response.code == 235 {
    True -> Ok(Nil)
    False -> Error(AuthenticationFailed(response.message))
  }
}

fn auth_login(
  socket: Socket,
  is_tls: Bool,
  creds: Credentials,
  timeout: Int,
) -> SmtpResult(Nil) {
  // Send AUTH LOGIN
  use _ <- result.try(send_command(socket, is_tls, "AUTH LOGIN", timeout))
  use response <- result.try(read_response(socket, is_tls, timeout))
  use _ <- result.try(case response.code == 334 {
    False -> Error(AuthenticationFailed(response.message))
    True -> Ok(Nil)
  })

  // Send username
  let username = auth.encode_login_username(creds)
  use _ <- result.try(send_command(socket, is_tls, username, timeout))
  use response <- result.try(read_response(socket, is_tls, timeout))
  use _ <- result.try(case response.code == 334 {
    False -> Error(AuthenticationFailed(response.message))
    True -> Ok(Nil)
  })

  // Send password
  let password = auth.encode_login_password(creds)
  use _ <- result.try(send_command(socket, is_tls, password, timeout))
  use response <- result.try(read_response(socket, is_tls, timeout))
  case response.code == 235 {
    True -> Ok(Nil)
    False -> Error(AuthenticationFailed(response.message))
  }
}

fn auth_cram_md5(
  socket: Socket,
  is_tls: Bool,
  creds: Credentials,
  timeout: Int,
) -> SmtpResult(Nil) {
  // Send AUTH CRAM-MD5
  use _ <- result.try(send_command(socket, is_tls, "AUTH CRAM-MD5", timeout))
  use response <- result.try(read_response(socket, is_tls, timeout))
  use _ <- result.try(case response.code == 334 {
    False -> Error(AuthenticationFailed(response.message))
    True -> Ok(Nil)
  })

  // Compute and send response
  let challenge = response.message
  let response_str = auth.encode_cram_md5(creds, challenge)
  use _ <- result.try(send_command(socket, is_tls, response_str, timeout))
  use response <- result.try(read_response(socket, is_tls, timeout))
  case response.code == 235 {
    True -> Ok(Nil)
    False -> Error(AuthenticationFailed(response.message))
  }
}

fn auth_xoauth2(
  socket: Socket,
  is_tls: Bool,
  creds: Credentials,
  timeout: Int,
) -> SmtpResult(Nil) {
  let encoded = auth.encode_xoauth2(creds)
  use _ <- result.try(send_command(
    socket,
    is_tls,
    "AUTH XOAUTH2 " <> encoded,
    timeout,
  ))
  use response <- result.try(read_response(socket, is_tls, timeout))
  case response.code == 235 {
    True -> Ok(Nil)
    False -> Error(AuthenticationFailed(response.message))
  }
}

fn check_response_code(
  response: SmtpResponse,
  expected_code: Int,
) -> SmtpResult(Nil) {
  case response.code == expected_code {
    True -> Ok(Nil)
    False -> Error(CommandRejected(response.code, response.message))
  }
}

fn check_response_code_250_251(response: SmtpResponse) -> SmtpResult(Nil) {
  case response.code == 250 || response.code == 251 {
    True -> Ok(Nil)
    False -> Error(CommandRejected(response.code, response.message))
  }
}

// Network operations - delegated to lumenmail/network module

fn tcp_connect(host: String, port: Int, timeout: Int) -> SmtpResult(Socket) {
  network.tcp_connect(host, port, timeout)
}

fn ssl_connect(
  socket: Socket,
  host: String,
  allow_invalid_certs: Bool,
  timeout: Int,
) -> SmtpResult(Socket) {
  network.ssl_connect(socket, host, allow_invalid_certs, timeout)
}

fn send_command(
  socket: Socket,
  is_tls: Bool,
  command: String,
  timeout: Int,
) -> SmtpResult(Nil) {
  network.send_command(socket, is_tls, command, timeout)
}

fn send_data(
  socket: Socket,
  is_tls: Bool,
  data: String,
  timeout: Int,
) -> SmtpResult(Nil) {
  network.send_data(socket, is_tls, data, timeout)
}

fn read_response(
  socket: Socket,
  is_tls: Bool,
  timeout: Int,
) -> SmtpResult(SmtpResponse) {
  network.read_response(socket, is_tls, timeout)
}

fn read_multiline_response(
  socket: Socket,
  is_tls: Bool,
  timeout: Int,
) -> SmtpResult(SmtpResponse) {
  network.read_multiline_response(socket, is_tls, timeout)
}

fn close_socket(socket: Socket, is_tls: Bool) -> Nil {
  network.close_socket(socket, is_tls)
}
