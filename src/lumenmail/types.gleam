//// Core types for the lumenmail library.
//// This module defines all the fundamental types used throughout the library.

import gleam/option.{type Option}

/// Represents an email address with an optional display name.
pub type Address {
  Address(name: Option(String), email: String)
}

/// Constructs an Address from just an email string.
pub fn address(email: String) -> Address {
  Address(name: option.None, email: email)
}

/// Constructs an Address with both name and email.
pub fn address_with_name(name: String, email: String) -> Address {
  Address(name: option.Some(name), email: email)
}

/// Authentication credentials for SMTP.
pub type Credentials {
  /// Username and password authentication
  Plain(username: String, password: String)
  /// OAuth2 token authentication (for services like Gmail)
  OAuth2(username: String, token: String)
}

/// TLS configuration options.
pub type TlsMode {
  /// No TLS (plain text connection) - Not recommended for production
  None
  /// Start with plain connection, upgrade to TLS via STARTTLS command
  StartTls
  /// Connect directly using TLS (implicit TLS)
  ImplicitTls
}

/// SMTP authentication mechanisms.
pub type AuthMechanism {
  /// PLAIN authentication (base64 encoded)
  AuthPlain
  /// LOGIN authentication
  AuthLogin
  /// CRAM-MD5 authentication (challenge-response)
  AuthCramMd5
  /// XOAUTH2 for OAuth2 providers like Gmail
  AuthXOAuth2
}

/// Errors that can occur during SMTP operations.
pub type SmtpError {
  /// Failed to establish TCP connection
  ConnectionFailed(reason: String)
  /// TLS handshake failed
  TlsError(reason: String)
  /// Authentication failed
  AuthenticationFailed(reason: String)
  /// SMTP command was rejected by server
  CommandRejected(code: Int, message: String)
  /// Invalid email address format
  InvalidAddress(address: String)
  /// Message was rejected by server
  MessageRejected(reason: String)
  /// Connection timeout
  Timeout
  /// DNS resolution failed
  DnsError(reason: String)
  /// Server closed connection unexpectedly
  ConnectionClosed
  /// Invalid server response
  InvalidResponse(response: String)
  /// General IO error
  IoError(reason: String)
}

/// Result type for SMTP operations.
pub type SmtpResult(a) =
  Result(a, SmtpError)

/// SMTP response from server.
pub type SmtpResponse {
  SmtpResponse(code: Int, message: String, is_multiline: Bool)
}

/// Connection state.
pub type ConnectionState {
  Disconnected
  Connected
  Authenticated
}

/// Server capabilities discovered via EHLO.
pub type ServerCapabilities {
  ServerCapabilities(
    /// Server supports STARTTLS
    starttls: Bool,
    /// Supported authentication mechanisms
    auth_mechanisms: List(AuthMechanism),
    /// Server supports 8-bit MIME
    eight_bit_mime: Bool,
    /// Server supports pipelining
    pipelining: Bool,
    /// Maximum message size (0 = unlimited)
    size: Int,
    /// Server supports DSN (Delivery Status Notifications)
    dsn: Bool,
    /// Raw EHLO response lines
    extensions: List(String),
  )
}

/// Creates default/empty server capabilities.
pub fn empty_capabilities() -> ServerCapabilities {
  ServerCapabilities(
    starttls: False,
    auth_mechanisms: [],
    eight_bit_mime: False,
    pipelining: False,
    size: 0,
    dsn: False,
    extensions: [],
  )
}
