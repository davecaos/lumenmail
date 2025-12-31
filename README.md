# LumenMail

A Gleam library for sending emails via SMTP, inspired by the Rust [mail-send](https://docs.rs/mail-send/latest/mail_send/) crate.

[![Package Version](https://img.shields.io/hexpm/v/lumenmail)](https://hex.pm/packages/lumenmail)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/lumenmail/)

## Features

- Direct SMTP connections with TLS/SSL support
- STARTTLS and implicit TLS (port 465)
- Multiple authentication mechanisms (PLAIN, LOGIN, CRAM-MD5, XOAUTH2)
- HTML and plain text emails
- File attachments and inline images
- Custom headers
- Email threading (In-Reply-To, References)
- RFC 5322 compliant message formatting
- Connection reuse for sending multiple emails

## Installation

Add `lumenmail` to your Gleam project:

```sh
gleam add lumenmail
```

## Quick Start

```gleam
import lumenmail/message
import lumenmail/smtp

pub fn main() {
  // Build the email message
  let email = message.new()
    |> message.from_name_email("John Doe", "john@example.com")
    |> message.to_email("recipient@example.com")
    |> message.subject("Hello from Gleam!")
    |> message.text_body("This is a test email sent with lumenmail.")

  // Connect to SMTP server and send
  let assert Ok(client) = smtp.builder("smtp.example.com", 587)
    |> smtp.auth("username", "password")
    |> smtp.connect()

  let assert Ok(_) = smtp.send(client, email)
  let assert Ok(_) = smtp.close(client)
}
```

## Examples

### Simple Text Email

```gleam
import lumenmail/message
import lumenmail/smtp

pub fn send_simple_email() {
  let email = message.new()
    |> message.from_email("sender@example.com")
    |> message.to_email("recipient@example.com")
    |> message.subject("Hello!")
    |> message.text_body("This is a plain text email.")

  let assert Ok(client) = smtp.builder("smtp.example.com", 587)
    |> smtp.auth("user", "password")
    |> smtp.connect()

  let assert Ok(_) = smtp.send(client, email)
  let assert Ok(_) = smtp.close(client)
}
```

### HTML Email with Plain Text Fallback

```gleam
import lumenmail/message
import lumenmail/smtp

pub fn send_html_email() {
  let email = message.new()
    |> message.from_name_email("Newsletter", "news@example.com")
    |> message.to_email("subscriber@example.com")
    |> message.subject("Weekly Newsletter")
    |> message.text_body("Your weekly update in plain text.")
    |> message.html_body("<h1>Weekly Newsletter</h1><p>Your weekly update!</p>")

  let assert Ok(client) = smtp.builder("smtp.example.com", 587)
    |> smtp.auth("user", "password")
    |> smtp.connect()

  let assert Ok(_) = smtp.send(client, email)
  let assert Ok(_) = smtp.close(client)
}
```

### Email with Attachments

```gleam
import lumenmail/message
import lumenmail/smtp

pub fn send_with_attachment() {
  let pdf_data = <<...>>  // Your PDF file as BitArray

  let email = message.new()
    |> message.from_email("sender@example.com")
    |> message.to_email("recipient@example.com")
    |> message.subject("Document Attached")
    |> message.text_body("Please find the document attached.")
    |> message.attachment("document.pdf", message.ApplicationOctetStream, pdf_data)

  let assert Ok(client) = smtp.builder("smtp.example.com", 587)
    |> smtp.auth("user", "password")
    |> smtp.connect()

  let assert Ok(_) = smtp.send(client, email)
  let assert Ok(_) = smtp.close(client)
}
```

### Multiple Recipients (To, CC, BCC)

```gleam
import lumenmail/message
import lumenmail/smtp

pub fn send_to_multiple() {
  let email = message.new()
    |> message.from_email("sender@example.com")
    |> message.to_email("primary@example.com")
    |> message.to_name_email("Jane Doe", "jane@example.com")
    |> message.cc_email("cc@example.com")
    |> message.bcc_email("bcc@example.com")
    |> message.subject("Team Update")
    |> message.text_body("Hello team!")

  let assert Ok(client) = smtp.builder("smtp.example.com", 587)
    |> smtp.auth("user", "password")
    |> smtp.connect()

  let assert Ok(_) = smtp.send(client, email)
  let assert Ok(_) = smtp.close(client)
}
```

### Using Gmail with App Password

```gleam
import lumenmail/message
import lumenmail/smtp

pub fn send_via_gmail() {
  let email = message.new()
    |> message.from_email("your.email@gmail.com")
    |> message.to_email("recipient@example.com")
    |> message.subject("Sent from Gmail")
    |> message.text_body("Hello from Gmail!")

  // Gmail uses port 587 with STARTTLS
  let assert Ok(client) = smtp.builder("smtp.gmail.com", 587)
    |> smtp.auth("your.email@gmail.com", "your-app-password")
    |> smtp.connect()

  let assert Ok(_) = smtp.send(client, email)
  let assert Ok(_) = smtp.close(client)
}
```

### Using Implicit TLS (Port 465)

```gleam
import lumenmail/message
import lumenmail/smtp

pub fn send_with_implicit_tls() {
  let email = message.new()
    |> message.from_email("sender@example.com")
    |> message.to_email("recipient@example.com")
    |> message.subject("Secure Email")
    |> message.text_body("Sent over implicit TLS.")

  // Port 465 automatically uses implicit TLS
  let assert Ok(client) = smtp.builder("smtp.example.com", 465)
    |> smtp.auth("user", "password")
    |> smtp.connect()

  let assert Ok(_) = smtp.send(client, email)
  let assert Ok(_) = smtp.close(client)
}
```

### OAuth2 Authentication

```gleam
import lumenmail/message
import lumenmail/smtp
import lumenmail/types

pub fn send_with_oauth2() {
  let email = message.new()
    |> message.from_email("user@gmail.com")
    |> message.to_email("recipient@example.com")
    |> message.subject("OAuth2 Email")
    |> message.text_body("Sent using OAuth2!")

  let assert Ok(client) = smtp.builder("smtp.gmail.com", 587)
    |> smtp.credentials(types.OAuth2("user@gmail.com", "oauth2-access-token"))
    |> smtp.connect()

  let assert Ok(_) = smtp.send(client, email)
  let assert Ok(_) = smtp.close(client)
}
```

### Sending Multiple Emails (Connection Reuse)

```gleam
import lumenmail/message
import lumenmail/smtp

pub fn send_multiple_emails() {
  let assert Ok(client) = smtp.builder("smtp.example.com", 587)
    |> smtp.auth("user", "password")
    |> smtp.connect()

  // Send first email
  let email1 = message.new()
    |> message.from_email("sender@example.com")
    |> message.to_email("recipient1@example.com")
    |> message.subject("Email 1")
    |> message.text_body("First email")

  let assert Ok(_) = smtp.send(client, email1)

  // Reset connection state
  let assert Ok(_) = smtp.reset(client)

  // Send second email
  let email2 = message.new()
    |> message.from_email("sender@example.com")
    |> message.to_email("recipient2@example.com")
    |> message.subject("Email 2")
    |> message.text_body("Second email")

  let assert Ok(_) = smtp.send(client, email2)
  let assert Ok(_) = smtp.close(client)
}
```

## API Reference

### Message Builder

| Function | Description |
|----------|-------------|
| `message.new()` | Create a new empty message |
| `message.from_email(msg, email)` | Set sender email |
| `message.from_name_email(msg, name, email)` | Set sender with display name |
| `message.to_email(msg, email)` | Add To recipient |
| `message.to_name_email(msg, name, email)` | Add To recipient with name |
| `message.cc_email(msg, email)` | Add CC recipient |
| `message.bcc_email(msg, email)` | Add BCC recipient |
| `message.subject(msg, subject)` | Set subject line |
| `message.text_body(msg, text)` | Set plain text body |
| `message.html_body(msg, html)` | Set HTML body |
| `message.attachment(msg, filename, content_type, data)` | Add file attachment |
| `message.inline_attachment(msg, filename, content_type, data, content_id)` | Add inline attachment |
| `message.header(msg, name, value)` | Add custom header |
| `message.priority(msg, priority)` | Set email priority |
| `message.reply_to(msg, address)` | Set Reply-To address |

### SMTP Client Builder

| Function | Description |
|----------|-------------|
| `smtp.builder(host, port)` | Create SMTP client builder |
| `smtp.auth(builder, username, password)` | Set authentication credentials |
| `smtp.credentials(builder, creds)` | Set credentials (Plain or OAuth2) |
| `smtp.implicit_tls(builder, enabled)` | Enable/disable implicit TLS |
| `smtp.timeout(builder, ms)` | Set connection timeout |
| `smtp.helo_host(builder, hostname)` | Set HELO hostname |
| `smtp.allow_invalid_certs(builder, allow)` | Allow invalid TLS certs (testing only) |
| `smtp.connect(builder)` | Connect to SMTP server |

### SMTP Client Operations

| Function | Description |
|----------|-------------|
| `smtp.send(client, message)` | Send an email message |
| `smtp.send_raw(client, from, to, data)` | Send raw email data |
| `smtp.reset(client)` | Reset connection for next email |
| `smtp.noop(client)` | Send NOOP to keep connection alive |
| `smtp.close(client)` | Close the connection |
| `smtp.capabilities(client)` | Get server capabilities |

## Common SMTP Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 25 | SMTP | Standard SMTP (often blocked by ISPs) |
| 587 | Submission | SMTP with STARTTLS (recommended) |
| 465 | SMTPS | SMTP over implicit TLS |

## Development

```sh
gleam test  # Run the tests
gleam build # Build the project
```

## License

Apache-2.0 OR MIT
