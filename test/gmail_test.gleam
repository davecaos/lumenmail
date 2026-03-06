//// Gmail SMTP Relay Test Script
////
//// This script tests sending emails through Gmail's SMTP relay.
////
//// Configuration:
//// Set the following environment variables before running:
////   GMAIL_SENDER_EMAIL - Your Gmail address (e.g., myapp.sender@gmail.com)
////   GMAIL_APP_PASSWORD - Your Gmail App Password (16 characters, no spaces)
////   SMTP_SERVER        - SMTP server (default: smtp.gmail.com)
////   TEST_RECIPIENT     - Email address to send test email to
////
//// To generate a Gmail App Password:
//// 1. Go to https://myaccount.google.com/apppasswords
//// 2. Select "Mail" and your device
//// 3. Copy the 16-character password (remove spaces)
////
//// Usage:
////   export GMAIL_SENDER_EMAIL="myapp.notifications@gmail.com"
////   export GMAIL_APP_PASSWORD="abcd efgh ijkl mnop"
////   export TEST_RECIPIENT="recipient@example.com"
////   gleam run -m examples/gmail_test

import envoy
import gleam/int
import gleam/io
import gleam/result
import lumenmail/message
import lumenmail/smtp
import lumenmail/types

// Default configuration values (used when environment variables are not set)
const default_sender_email = "myapp.notifications@gmail.com"

const default_sender_name = "MyApp Notifications"

const default_app_password = "xxxx xxxx xxxx xxxx"

const default_smtp_server = "smtp.gmail.com"

const default_smtp_port = 587

const default_test_recipient = "test.recipient@example.com"

// Helper function to get environment variable or use default
fn get_env_or(name: String, default: String) -> String {
  case envoy.get(name) {
    Ok(value) -> value
    Error(_) -> default
  }
}

pub fn main() {
  // Get configuration from environment variables, with fallback to defaults
  let sender_email = get_env_or("GMAIL_SENDER_EMAIL", default_sender_email)
  let sender_name = get_env_or("GMAIL_SENDER_NAME", default_sender_name)
  let app_password = get_env_or("GMAIL_APP_PASSWORD", default_app_password)
  let smtp_server = get_env_or("SMTP_SERVER", default_smtp_server)
  let smtp_port = case envoy.get("SMTP_PORT") {
    Ok(port_str) ->
      case int.parse(port_str) {
        Ok(port) -> port
        Error(_) -> default_smtp_port
      }
    Error(_) -> default_smtp_port
  }
  let test_recipient = get_env_or("TEST_RECIPIENT", default_test_recipient)
  io.println("===========================================")
  io.println("  Gmail SMTP Relay Test")
  io.println("===========================================")
  io.println("")
  io.println("Configuration:")
  io.println(
    "  SMTP Server: " <> smtp_server <> ":" <> int.to_string(smtp_port),
  )
  io.println("  Sender: " <> sender_email)
  io.println("  Recipient: " <> test_recipient)
  io.println("")

  // Build a test email
  let email =
    message.new()
    |> message.from_name_email(sender_name, sender_email)
    |> message.to_email(test_recipient)
    |> message.subject("Test Email from LumenMail Library")
    |> message.text_body("Hello!

This is a test email sent using the Gleam LumenMail library.

If you received this email, the SMTP relay is working correctly!

Configuration used:
- SMTP Server: " <> smtp_server <> "
- Port: " <> int.to_string(smtp_port) <> " (STARTTLS)
- Sender: " <> sender_email <> "

Best regards,
LumenMail Test Script")
    |> message.html_body("<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
    .header { background: #ffaff3; color: #2d1a26; padding: 20px; text-align: center; }
    .header .star { font-size: 60px; margin-bottom: 10px; }
    .header h1 { margin: 0; color: #584355; }
    .content { padding: 20px; background: #f9f9f9; }
    .config { background: #ffe8fb; padding: 15px; border-radius: 5px; margin: 15px 0; border: 1px solid #ffaff3; }
    .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
  </style>
</head>
<body>
  <div class=\"container\">
    <div class=\"header\">
      <div class=\"star\">⭐</div>
      <h1>Test Email</h1>
    </div>
    <div class=\"content\">
      <p>Hello!</p>
      <p>This is a <strong>test email</strong> sent using the Gleam LumenMail library.</p>
      <p>If you received this email, the SMTP relay is working correctly!</p>

      <div class=\"config\">
        <h3>Configuration Used:</h3>
        <ul>
          <li><strong>SMTP Server:</strong> " <> smtp_server <> "</li>
          <li><strong>Port:</strong> " <> int.to_string(smtp_port) <> " (STARTTLS)</li>
          <li><strong>Sender:</strong> " <> sender_email <> "</li>
        </ul>
      </div>
    </div>
    <div class=\"footer\">
      <p>⭐ Sent with LumenMail - A Gleam SMTP Library ⭐</p>
    </div>
  </div>
</body>
</html>")

  io.println("Connecting to SMTP server...")

  // Connect to Gmail SMTP
  let connect_result =
    smtp.builder(smtp_server, smtp_port)
    |> smtp.auth(sender_email, app_password)
    |> smtp.timeout(30_000)
    |> smtp.connect()

  case connect_result {
    Ok(client) -> {
      io.println("Connected successfully!")
      io.println("")
      io.println("Sending email...")

      case smtp.send(client, email) {
        Ok(_) -> {
          io.println("Email sent successfully!")
          io.println("")
          io.println("Check " <> test_recipient <> " for the test email.")
        }
        Error(err) -> {
          io.println("Failed to send email!")
          io.println("Error: " <> format_error(err))
        }
      }

      // Close connection
      let _ = smtp.close(client)
      io.println("")
      io.println("Connection closed.")
    }
    Error(err) -> {
      io.println("Failed to connect!")
      io.println("Error: " <> format_error(err))
      io.println("")
      io.println("Troubleshooting tips:")
      io.println("  1. Check your Gmail App Password is correct")
      io.println("  2. Ensure 2FA is enabled on your Google account")
      io.println("  3. Verify the sender email address is correct")
      io.println("  4. Check your network/firewall allows outbound port 587")
    }
  }

  io.println("")
  io.println("===========================================")
}

fn format_error(err: types.SmtpError) -> String {
  case err {
    types.ConnectionFailed(reason) -> "Connection failed: " <> reason
    types.TlsError(reason) -> "TLS error: " <> reason
    types.AuthenticationFailed(reason) -> "Authentication failed: " <> reason
    types.CommandRejected(code, msg) ->
      "Command rejected (" <> int.to_string(code) <> "): " <> msg
    types.MessageRejected(reason) -> "Message rejected: " <> reason
    types.Timeout -> "Connection timeout"
    types.ConnectionClosed -> "Connection closed unexpectedly"
    types.InvalidResponse(resp) -> "Invalid response: " <> resp
    types.IoError(reason) -> "IO error: " <> reason
    types.DnsError(reason) -> "DNS error: " <> reason
    types.InvalidAddress(addr) -> "Invalid address: " <> addr
  }
}
