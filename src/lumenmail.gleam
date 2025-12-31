//// LumenMail - A Gleam library for sending emails via SMTP.
////
//// Inspired by the Rust [mail-send](https://docs.rs/mail-send/latest/mail_send/) crate.
////
//// ## Example
////
//// ```gleam
//// import lumenmail
//// import lumenmail/message
//// import lumenmail/smtp
////
//// pub fn main() {
////   let email = message.new()
////     |> message.from_name_email("Sender", "sender@example.com")
////     |> message.to_email("recipient@example.com")
////     |> message.subject("Hello from Gleam!")
////     |> message.text_body("This is a test email sent with lumenmail.")
////
////   let assert Ok(client) = smtp.builder("smtp.example.com", 587)
////     |> smtp.auth("username", "password")
////     |> smtp.connect()
////
////   let assert Ok(_) = smtp.send(client, email)
////   let assert Ok(_) = smtp.close(client)
//// }
//// ```

// Re-export main types and functions for convenience
import lumenmail/message
import lumenmail/smtp
import lumenmail/types

/// Creates a new SMTP client builder for the given host and port.
///
/// Common ports:
/// - 25: Standard SMTP (often blocked by ISPs)
/// - 587: Submission with STARTTLS (recommended)
/// - 465: SMTPS with implicit TLS
///
/// ## Example
///
/// ```gleam
/// let builder = lumenmail.smtp_builder("smtp.gmail.com", 587)
///   |> lumenmail.with_auth("user@gmail.com", "app-password")
/// ```
pub fn smtp_builder(host: String, port: Int) -> smtp.SmtpClientBuilder {
  smtp.builder(host, port)
}

/// Adds username/password authentication to the builder.
pub fn with_auth(
  builder: smtp.SmtpClientBuilder,
  username: String,
  password: String,
) -> smtp.SmtpClientBuilder {
  smtp.auth(builder, username, password)
}

/// Adds OAuth2 authentication to the builder.
pub fn with_oauth2(
  builder: smtp.SmtpClientBuilder,
  username: String,
  token: String,
) -> smtp.SmtpClientBuilder {
  smtp.credentials(builder, types.OAuth2(username, token))
}

/// Sets implicit TLS mode (for port 465).
pub fn with_implicit_tls(
  builder: smtp.SmtpClientBuilder,
  enabled: Bool,
) -> smtp.SmtpClientBuilder {
  smtp.implicit_tls(builder, enabled)
}

/// Sets the connection timeout in milliseconds.
pub fn with_timeout(
  builder: smtp.SmtpClientBuilder,
  timeout_ms: Int,
) -> smtp.SmtpClientBuilder {
  smtp.timeout(builder, timeout_ms)
}

/// Allows invalid/self-signed TLS certificates.
/// Warning: Only use this for testing!
pub fn allow_invalid_certs(
  builder: smtp.SmtpClientBuilder,
  allow: Bool,
) -> smtp.SmtpClientBuilder {
  smtp.allow_invalid_certs(builder, allow)
}

/// Connects to the SMTP server using the builder configuration.
pub fn connect(
  builder: smtp.SmtpClientBuilder,
) -> types.SmtpResult(smtp.SmtpClient) {
  smtp.connect(builder)
}

/// Creates a new empty email message builder.
///
/// ## Example
///
/// ```gleam
/// let email = lumenmail.new_message()
///   |> message.from_email("sender@example.com")
///   |> message.to_email("recipient@example.com")
///   |> message.subject("Hello!")
///   |> message.text_body("Email content here.")
/// ```
pub fn new_message() -> message.Message {
  message.new()
}

/// Sends an email using the connected client.
pub fn send(
  client: smtp.SmtpClient,
  email: message.Message,
) -> types.SmtpResult(Nil) {
  smtp.send(client, email)
}

/// Closes the SMTP connection.
pub fn close(client: smtp.SmtpClient) -> types.SmtpResult(Nil) {
  smtp.close(client)
}

/// Resets the connection for sending another email.
pub fn reset(client: smtp.SmtpClient) -> types.SmtpResult(Nil) {
  smtp.reset(client)
}
