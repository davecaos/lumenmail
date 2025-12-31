//// SMTP Relay Test Script with Environment Variables
////
//// This script tests sending emails through any SMTP relay using
//// configuration from environment variables.
////
//// Required environment variables:
////   SMTP_SENDER_EMAIL  - Sender email address
////   SMTP_APP_PASSWORD  - SMTP password or app password
////   SMTP_RECIPIENT     - Recipient email address
////
//// Optional environment variables:
////   SMTP_SERVER        - SMTP server hostname (default: smtp.gmail.com)
////   SMTP_PORT          - SMTP port (default: 587)
////   SMTP_SENDER_NAME   - Display name for sender (default: "Test Sender")
////
//// Usage:
////   export SMTP_SENDER_EMAIL="notifications@example.com"
////   export SMTP_APP_PASSWORD="your-password-here"
////   export SMTP_RECIPIENT="recipient@example.com"
////   gleam run -m examples/smtp_relay_test

import envoy
import gleam/int
import gleam/io
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import lumenmail/message
import lumenmail/smtp
import lumenmail/types

pub fn main() {
  io.println("===========================================")
  io.println("  SMTP Relay Test")
  io.println("===========================================")
  io.println("")

  // Read configuration from environment
  let sender_email = get_env("SMTP_SENDER_EMAIL")
  let app_password = get_env("SMTP_APP_PASSWORD")
  let recipient = get_env("SMTP_RECIPIENT")
  let smtp_server = get_env_or("SMTP_SERVER", "smtp.gmail.com")
  let sender_name = get_env_or("SMTP_SENDER_NAME", "Test Sender")
  let smtp_port =
    get_env_or("SMTP_PORT", "587")
    |> int.parse
    |> result.unwrap(587)

  // Validate required configuration
  case sender_email, app_password, recipient {
    Some(sender), Some(password), Some(to) -> {
      io.println("Configuration:")
      io.println("  SMTP Server: " <> smtp_server <> ":" <> int.to_string(smtp_port))
      io.println("  Sender: " <> sender_name <> " <" <> sender <> ">")
      io.println("  Recipient: " <> to)
      io.println("  Password: ****" <> mask_password(password))
      io.println("")

      run_test(smtp_server, smtp_port, sender, sender_name, password, to)
    }
    _, _, _ -> {
      io.println("ERROR: Missing required environment variables!")
      io.println("")
      io.println("Required variables:")
      print_env_status("SMTP_SENDER_EMAIL", sender_email)
      print_env_status("SMTP_APP_PASSWORD", app_password)
      print_env_status("SMTP_RECIPIENT", recipient)
      io.println("")
      io.println("Example usage:")
      io.println("  export SMTP_SENDER_EMAIL=\"notifications@gmail.com\"")
      io.println("  export SMTP_APP_PASSWORD=\"abcd efgh ijkl mnop\"")
      io.println("  export SMTP_RECIPIENT=\"test@example.com\"")
      io.println("  gleam run -m examples/smtp_relay_test")
    }
  }

  io.println("")
  io.println("===========================================")
}

fn run_test(
  smtp_server: String,
  smtp_port: Int,
  sender_email: String,
  sender_name: String,
  password: String,
  recipient: String,
) {
  // Build a test email
  let email =
    message.new()
    |> message.from_name_email(sender_name, sender_email)
    |> message.to_email(recipient)
    |> message.subject("SMTP Relay Test - " <> get_timestamp())
    |> message.text_body(
      "Hello!

This is a test email sent using the Gleam mailsend library.

If you received this email, your SMTP relay configuration is working correctly!

Configuration:
- Server: " <> smtp_server <> ":" <> int.to_string(smtp_port) <> "
- Sender: " <> sender_email <> "

Best regards,
SMTP Relay Test",
    )
    |> message.html_body(
      "<html>
<body style=\"font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;\">
  <div style=\"background: #2196F3; color: white; padding: 20px; text-align: center;\">
    <h1 style=\"margin: 0;\">SMTP Relay Test</h1>
  </div>
  <div style=\"padding: 20px; background: #f5f5f5;\">
    <p>Hello!</p>
    <p>This is a <strong>test email</strong> sent using the Gleam mailsend library.</p>
    <p style=\"color: #4CAF50; font-weight: bold;\">
      If you received this email, your SMTP relay configuration is working correctly!
    </p>
    <div style=\"background: white; padding: 15px; border-radius: 5px; margin: 15px 0;\">
      <h3 style=\"margin-top: 0;\">Configuration:</h3>
      <ul>
        <li><strong>Server:</strong> " <> smtp_server <> ":" <> int.to_string(smtp_port) <> "</li>
        <li><strong>Sender:</strong> " <> sender_email <> "</li>
      </ul>
    </div>
  </div>
  <div style=\"text-align: center; padding: 15px; color: #666; font-size: 12px;\">
    Sent with Mailsend - A Gleam SMTP Library
  </div>
</body>
</html>",
    )

  io.println("Connecting to " <> smtp_server <> ":" <> int.to_string(smtp_port) <> "...")

  // Connect to SMTP server
  let connect_result =
    smtp.builder(smtp_server, smtp_port)
    |> smtp.auth(sender_email, password)
    |> smtp.timeout(30_000)
    |> smtp.connect()

  case connect_result {
    Ok(client) -> {
      io.println("Connected!")

      // Show server capabilities
      let caps = smtp.capabilities(client)
      io.println("Server capabilities:")
      io.println("  - STARTTLS: " <> bool_to_string(caps.starttls))
      io.println("  - 8BITMIME: " <> bool_to_string(caps.eight_bit_mime))
      io.println("  - PIPELINING: " <> bool_to_string(caps.pipelining))
      io.println("")

      io.println("Sending email to " <> recipient <> "...")

      case smtp.send(client, email) {
        Ok(_) -> {
          io.println("")
          io.println("SUCCESS! Email sent successfully!")
          io.println("Check " <> recipient <> " for the test email.")
        }
        Error(err) -> {
          io.println("")
          io.println("FAILED to send email!")
          io.println("Error: " <> format_error(err))
        }
      }

      // Close connection
      let _ = smtp.close(client)
      io.println("")
      io.println("Connection closed.")
    }
    Error(err) -> {
      io.println("")
      io.println("FAILED to connect!")
      io.println("Error: " <> format_error(err))
      io.println("")
      io.println("Troubleshooting:")
      io.println("  1. Verify SMTP server and port are correct")
      io.println("  2. Check credentials (use App Password for Gmail)")
      io.println("  3. Ensure firewall allows outbound connections on port " <> int.to_string(smtp_port))
      io.println("  4. For Gmail: Enable 2FA and create an App Password")
    }
  }
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

fn print_env_status(name: String, value: Option(String)) {
  case value {
    Some(_) -> io.println("  " <> name <> ": [SET]")
    None -> io.println("  " <> name <> ": [MISSING]")
  }
}

fn mask_password(password: String) -> String {
  // Show last 4 characters only
  let len = string.length(password)
  case len > 4 {
    True -> string.slice(password, len - 4, 4)
    False -> "****"
  }
}

fn bool_to_string(b: Bool) -> String {
  case b {
    True -> "Yes"
    False -> "No"
  }
}

fn get_env(name: String) -> Option(String) {
  case envoy.get(name) {
    Ok(value) -> Some(value)
    Error(_) -> None
  }
}

fn get_env_or(name: String, default: String) -> String {
  case envoy.get(name) {
    Ok(value) -> value
    Error(_) -> default
  }
}

fn get_timestamp() -> String {
  // Simple timestamp placeholder - returns a static string
  // In production, you might want to use a proper datetime library like birl
  "Email Test"
}
