//// Network module for SMTP operations.
//// Provides TCP and SSL socket handling using Erlang's gen_tcp and ssl modules.
//// This is a pure Gleam implementation using @external declarations.

import gleam/int
import gleam/list
import gleam/string
import lumenmail/types.{
  type SmtpResponse, type SmtpResult, ConnectionClosed, ConnectionFailed,
  InvalidResponse, IoError, SmtpResponse, Timeout, TlsError,
}

/// Opaque socket type that can be either TCP or SSL socket.
pub type Socket

/// Options for TCP connection.
pub type TcpOption {
  Binary
  ActiveFalse
  PacketLine
  ReuseAddr
}

// =============================================================================
// TCP Connection
// =============================================================================

/// Establishes a TCP connection to the SMTP server.
pub fn tcp_connect(
  host: String,
  port: Int,
  timeout: Int,
) -> SmtpResult(Socket) {
  let options = [Binary, ActiveFalse, PacketLine, ReuseAddr]
  case do_tcp_connect(host, port, options, timeout) {
    Ok(socket) -> Ok(socket)
    Error(reason) -> Error(ConnectionFailed(format_error(reason)))
  }
}

@external(erlang, "lumenmail_network_ffi", "tcp_connect")
fn do_tcp_connect(
  host: String,
  port: Int,
  options: List(TcpOption),
  timeout: Int,
) -> Result(Socket, String)

// =============================================================================
// SSL/TLS Connection
// =============================================================================

/// Upgrades a TCP socket to SSL/TLS.
pub fn ssl_connect(
  socket: Socket,
  host: String,
  allow_invalid_certs: Bool,
  timeout: Int,
) -> SmtpResult(Socket) {
  // Ensure SSL application is started
  let _ = ensure_ssl_started()

  case do_ssl_connect(socket, host, allow_invalid_certs, timeout) {
    Ok(ssl_socket) -> Ok(ssl_socket)
    Error(reason) -> Error(TlsError(format_error(reason)))
  }
}

@external(erlang, "lumenmail_network_ffi", "ssl_connect")
fn do_ssl_connect(
  socket: Socket,
  host: String,
  allow_invalid_certs: Bool,
  timeout: Int,
) -> Result(Socket, String)

@external(erlang, "lumenmail_network_ffi", "ensure_ssl_started")
fn ensure_ssl_started() -> Nil

// =============================================================================
// Send Operations
// =============================================================================

/// Sends an SMTP command (appends CRLF).
pub fn send_command(
  socket: Socket,
  is_tls: Bool,
  command: String,
  _timeout: Int,
) -> SmtpResult(Nil) {
  let data = command <> "\r\n"
  case do_send(socket, is_tls, data) {
    Ok(Nil) -> Ok(Nil)
    Error(reason) -> Error(IoError(format_error(reason)))
  }
}

/// Sends raw data (for message body) with dot-stuffing.
pub fn send_data(
  socket: Socket,
  is_tls: Bool,
  data: String,
  _timeout: Int,
) -> SmtpResult(Nil) {
  // Apply dot-stuffing and normalize line endings
  let processed = process_email_data(data)
  case do_send(socket, is_tls, processed) {
    Ok(Nil) -> Ok(Nil)
    Error(reason) -> Error(IoError(format_error(reason)))
  }
}

/// Process email data: normalize line endings and apply dot-stuffing.
fn process_email_data(data: String) -> String {
  data
  |> string.split("\n")
  |> list.map(fn(line) {
    // Remove trailing CR if present
    let clean_line = case string.ends_with(line, "\r") {
      True -> string.drop_end(line, 1)
      False -> line
    }
    // Dot-stuffing: if line starts with dot, add another dot
    case string.starts_with(clean_line, ".") {
      True -> "." <> clean_line
      False -> clean_line
    }
  })
  |> string.join("\r\n")
}

@external(erlang, "lumenmail_network_ffi", "send")
fn do_send(socket: Socket, is_tls: Bool, data: String) -> Result(Nil, String)

// =============================================================================
// Receive Operations
// =============================================================================

/// Reads a single-line SMTP response.
pub fn read_response(
  socket: Socket,
  is_tls: Bool,
  timeout: Int,
) -> SmtpResult(SmtpResponse) {
  case do_recv(socket, is_tls, timeout) {
    Ok(line) -> parse_response_line(line)
    Error("closed") -> Error(ConnectionClosed)
    Error("timeout") -> Error(Timeout)
    Error(reason) -> Error(InvalidResponse(reason))
  }
}

/// Reads a multi-line SMTP response (e.g., EHLO response).
pub fn read_multiline_response(
  socket: Socket,
  is_tls: Bool,
  timeout: Int,
) -> SmtpResult(SmtpResponse) {
  read_multiline_loop(socket, is_tls, timeout, [])
}

fn read_multiline_loop(
  socket: Socket,
  is_tls: Bool,
  timeout: Int,
  acc: List(String),
) -> SmtpResult(SmtpResponse) {
  case do_recv(socket, is_tls, timeout) {
    Ok(line) -> {
      case parse_response_line(line) {
        Ok(SmtpResponse(_code, message, True)) -> {
          // More lines coming (code followed by -)
          read_multiline_loop(socket, is_tls, timeout, [message, ..acc])
        }
        Ok(SmtpResponse(code, message, False)) -> {
          // Last line (code followed by space)
          let all_messages = list.reverse([message, ..acc])
          let full_message = string.join(all_messages, "\n")
          Ok(SmtpResponse(code, full_message, False))
        }
        Error(e) -> Error(e)
      }
    }
    Error("closed") -> Error(ConnectionClosed)
    Error("timeout") -> Error(Timeout)
    Error(reason) -> Error(InvalidResponse(reason))
  }
}

@external(erlang, "lumenmail_network_ffi", "recv")
fn do_recv(socket: Socket, is_tls: Bool, timeout: Int) -> Result(String, String)

// =============================================================================
// Close Operations
// =============================================================================

/// Closes the socket.
pub fn close_socket(socket: Socket, is_tls: Bool) -> Nil {
  do_close(socket, is_tls)
}

@external(erlang, "lumenmail_network_ffi", "close")
fn do_close(socket: Socket, is_tls: Bool) -> Nil

// =============================================================================
// Helper Functions
// =============================================================================

/// Parse an SMTP response line into code, message, and multiline flag.
fn parse_response_line(line: String) -> SmtpResult(SmtpResponse) {
  // Remove trailing CRLF or LF
  let clean_line =
    line
    |> string.trim_end()

  case string.length(clean_line) >= 3 {
    False -> Error(InvalidResponse(line))
    True -> {
      let code_str = string.slice(clean_line, 0, 3)
      case int.parse(code_str) {
        Error(_) -> Error(InvalidResponse(line))
        Ok(code) -> {
          case string.length(clean_line) {
            3 -> Ok(SmtpResponse(code, "", False))
            _ -> {
              let separator = string.slice(clean_line, 3, 1)
              let message =
                string.slice(clean_line, 4, string.length(clean_line) - 4)
              let is_multiline = separator == "-"
              Ok(SmtpResponse(code, message, is_multiline))
            }
          }
        }
      }
    }
  }
}

/// Format an error reason to a string.
fn format_error(reason: String) -> String {
  reason
}
