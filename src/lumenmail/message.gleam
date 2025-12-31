//// Email message builder module.
//// Provides a fluent API for constructing RFC 5322 compliant email messages.

import gleam/bit_array
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/string_tree
import lumenmail/types.{type Address}

/// Content type for email body parts.
pub type ContentType {
  TextPlain
  TextHtml
  MultipartAlternative
  MultipartMixed
  MultipartRelated
  ApplicationOctetStream
  Custom(mime_type: String)
}

/// Content transfer encoding.
pub type Encoding {
  SevenBit
  EightBit
  QuotedPrintable
  Base64
}

/// An email attachment.
pub type Attachment {
  Attachment(
    filename: String,
    content_type: ContentType,
    data: BitArray,
    inline: Bool,
    content_id: Option(String),
  )
}

/// An email header.
pub type Header {
  Header(name: String, value: String)
}

/// Priority level for emails.
pub type Priority {
  High
  Normal
  Low
}

/// Email message structure.
pub type Message {
  Message(
    from: Option(Address),
    reply_to: Option(Address),
    to: List(Address),
    cc: List(Address),
    bcc: List(Address),
    subject: Option(String),
    text_body: Option(String),
    html_body: Option(String),
    attachments: List(Attachment),
    headers: List(Header),
    priority: Priority,
    message_id: Option(String),
    in_reply_to: Option(String),
    references: List(String),
  )
}

/// Creates a new empty message builder.
pub fn new() -> Message {
  Message(
    from: None,
    reply_to: None,
    to: [],
    cc: [],
    bcc: [],
    subject: None,
    text_body: None,
    html_body: None,
    attachments: [],
    headers: [],
    priority: Normal,
    message_id: None,
    in_reply_to: None,
    references: [],
  )
}

/// Sets the sender address.
pub fn from(message: Message, address: Address) -> Message {
  Message(..message, from: Some(address))
}

/// Sets the sender using just an email string.
pub fn from_email(message: Message, email: String) -> Message {
  Message(..message, from: Some(types.address(email)))
}

/// Sets the sender with name and email.
pub fn from_name_email(message: Message, name: String, email: String) -> Message {
  Message(..message, from: Some(types.address_with_name(name, email)))
}

/// Sets the reply-to address.
pub fn reply_to(message: Message, address: Address) -> Message {
  Message(..message, reply_to: Some(address))
}

/// Adds a recipient to the To field.
pub fn to(message: Message, address: Address) -> Message {
  Message(..message, to: list.append(message.to, [address]))
}

/// Adds a recipient to To using just an email string.
pub fn to_email(message: Message, email: String) -> Message {
  to(message, types.address(email))
}

/// Adds a recipient with name and email to To field.
pub fn to_name_email(message: Message, name: String, email: String) -> Message {
  to(message, types.address_with_name(name, email))
}

/// Sets multiple To recipients at once.
pub fn to_many(message: Message, addresses: List(Address)) -> Message {
  Message(..message, to: list.append(message.to, addresses))
}

/// Adds a recipient to the CC field.
pub fn cc(message: Message, address: Address) -> Message {
  Message(..message, cc: list.append(message.cc, [address]))
}

/// Adds a recipient to CC using just an email string.
pub fn cc_email(message: Message, email: String) -> Message {
  cc(message, types.address(email))
}

/// Sets multiple CC recipients at once.
pub fn cc_many(message: Message, addresses: List(Address)) -> Message {
  Message(..message, cc: list.append(message.cc, addresses))
}

/// Adds a recipient to the BCC field.
pub fn bcc(message: Message, address: Address) -> Message {
  Message(..message, bcc: list.append(message.bcc, [address]))
}

/// Adds a recipient to BCC using just an email string.
pub fn bcc_email(message: Message, email: String) -> Message {
  bcc(message, types.address(email))
}

/// Sets multiple BCC recipients at once.
pub fn bcc_many(message: Message, addresses: List(Address)) -> Message {
  Message(..message, bcc: list.append(message.bcc, addresses))
}

/// Sets the email subject.
pub fn subject(message: Message, subject: String) -> Message {
  Message(..message, subject: Some(subject))
}

/// Sets the plain text body.
pub fn text_body(message: Message, body: String) -> Message {
  Message(..message, text_body: Some(body))
}

/// Sets the HTML body.
pub fn html_body(message: Message, body: String) -> Message {
  Message(..message, html_body: Some(body))
}

/// Sets both text and HTML body (multipart/alternative).
pub fn body(message: Message, text: String, html: String) -> Message {
  message
  |> text_body(text)
  |> html_body(html)
}

/// Adds an attachment.
pub fn attachment(
  message: Message,
  filename: String,
  content_type: ContentType,
  data: BitArray,
) -> Message {
  let att =
    Attachment(
      filename: filename,
      content_type: content_type,
      data: data,
      inline: False,
      content_id: None,
    )
  Message(..message, attachments: list.append(message.attachments, [att]))
}

/// Adds an inline attachment (e.g., for images in HTML).
pub fn inline_attachment(
  message: Message,
  filename: String,
  content_type: ContentType,
  data: BitArray,
  content_id: String,
) -> Message {
  let att =
    Attachment(
      filename: filename,
      content_type: content_type,
      data: data,
      inline: True,
      content_id: Some(content_id),
    )
  Message(..message, attachments: list.append(message.attachments, [att]))
}

/// Adds a custom header.
pub fn header(message: Message, name: String, value: String) -> Message {
  Message(
    ..message,
    headers: list.append(message.headers, [Header(name, value)]),
  )
}

/// Sets the message priority.
pub fn priority(message: Message, priority: Priority) -> Message {
  Message(..message, priority: priority)
}

/// Sets the Message-ID header.
pub fn message_id(message: Message, id: String) -> Message {
  Message(..message, message_id: Some(id))
}

/// Sets the In-Reply-To header (for threading).
pub fn in_reply_to(message: Message, id: String) -> Message {
  Message(..message, in_reply_to: Some(id))
}

/// Adds a reference message ID (for threading).
pub fn add_reference(message: Message, id: String) -> Message {
  Message(..message, references: list.append(message.references, [id]))
}

/// Gets all recipients (to + cc + bcc).
pub fn all_recipients(message: Message) -> List(Address) {
  list.flatten([message.to, message.cc, message.bcc])
}

/// Formats an address for use in email headers.
pub fn format_address(address: Address) -> String {
  case address.name {
    Some(name) -> "\"" <> name <> "\" <" <> address.email <> ">"
    None -> address.email
  }
}

/// Formats a list of addresses for use in email headers.
pub fn format_address_list(addresses: List(Address)) -> String {
  addresses
  |> list.map(format_address)
  |> string.join(", ")
}

/// Converts content type to MIME string.
pub fn content_type_to_string(ct: ContentType) -> String {
  case ct {
    TextPlain -> "text/plain"
    TextHtml -> "text/html"
    MultipartAlternative -> "multipart/alternative"
    MultipartMixed -> "multipart/mixed"
    MultipartRelated -> "multipart/related"
    ApplicationOctetStream -> "application/octet-stream"
    Custom(mime) -> mime
  }
}

/// Generates a random boundary string for multipart messages.
pub fn generate_boundary() -> String {
  // Simple boundary - in production, use proper random generation
  "----=_Part_" <> "gleam_lumenmail_boundary_" <> "0123456789"
}

/// Builds the raw email message as a string.
pub fn build(message: Message) -> Result(String, String) {
  case message.from {
    None -> Error("From address is required")
    Some(from_addr) -> {
      case message.to {
        [] -> Error("At least one recipient is required")
        _ -> Ok(build_message_string(message, from_addr))
      }
    }
  }
}

fn build_message_string(message: Message, from_addr: Address) -> String {
  let builder = string_tree.new()
  let boundary = generate_boundary()

  // Build headers
  let builder =
    builder
    |> string_tree.append("From: " <> format_address(from_addr) <> "\r\n")

  let builder = case message.to {
    [] -> builder
    addrs ->
      builder
      |> string_tree.append("To: " <> format_address_list(addrs) <> "\r\n")
  }

  let builder = case message.cc {
    [] -> builder
    addrs ->
      builder
      |> string_tree.append("Cc: " <> format_address_list(addrs) <> "\r\n")
  }

  let builder = case message.reply_to {
    None -> builder
    Some(addr) ->
      builder
      |> string_tree.append("Reply-To: " <> format_address(addr) <> "\r\n")
  }

  let builder = case message.subject {
    None -> builder
    Some(subj) ->
      builder
      |> string_tree.append("Subject: " <> subj <> "\r\n")
  }

  let builder = case message.message_id {
    None -> builder
    Some(id) ->
      builder
      |> string_tree.append("Message-ID: <" <> id <> ">\r\n")
  }

  let builder = case message.in_reply_to {
    None -> builder
    Some(id) ->
      builder
      |> string_tree.append("In-Reply-To: <" <> id <> ">\r\n")
  }

  let builder = case message.references {
    [] -> builder
    refs -> {
      let refs_str =
        refs
        |> list.map(fn(r) { "<" <> r <> ">" })
        |> string.join(" ")
      builder
      |> string_tree.append("References: " <> refs_str <> "\r\n")
    }
  }

  // Add priority header
  let builder = case message.priority {
    High ->
      builder
      |> string_tree.append("X-Priority: 1\r\n")
      |> string_tree.append("Importance: high\r\n")
    Normal -> builder
    Low ->
      builder
      |> string_tree.append("X-Priority: 5\r\n")
      |> string_tree.append("Importance: low\r\n")
  }

  // Add custom headers
  let builder =
    list.fold(message.headers, builder, fn(b, h) {
      b
      |> string_tree.append(h.name <> ": " <> h.value <> "\r\n")
    })

  // Add MIME version
  let builder =
    builder
    |> string_tree.append("MIME-Version: 1.0\r\n")

  // Build body based on content
  let builder = case
    message.text_body,
    message.html_body,
    list.is_empty(message.attachments)
  {
    // Text only, no attachments
    Some(text), None, True ->
      builder
      |> string_tree.append(
        "Content-Type: text/plain; charset=utf-8\r\n\r\n",
      )
      |> string_tree.append(text)

    // HTML only, no attachments
    None, Some(html), True ->
      builder
      |> string_tree.append("Content-Type: text/html; charset=utf-8\r\n\r\n")
      |> string_tree.append(html)

    // Both text and HTML, no attachments
    Some(text), Some(html), True ->
      builder
      |> string_tree.append(
        "Content-Type: multipart/alternative; boundary=\""
        <> boundary
        <> "\"\r\n\r\n",
      )
      |> string_tree.append("--" <> boundary <> "\r\n")
      |> string_tree.append(
        "Content-Type: text/plain; charset=utf-8\r\n\r\n",
      )
      |> string_tree.append(text <> "\r\n\r\n")
      |> string_tree.append("--" <> boundary <> "\r\n")
      |> string_tree.append("Content-Type: text/html; charset=utf-8\r\n\r\n")
      |> string_tree.append(html <> "\r\n\r\n")
      |> string_tree.append("--" <> boundary <> "--\r\n")

    // With attachments - use multipart/mixed
    text_opt, html_opt, False -> {
      let mixed_boundary = boundary <> "_mixed"
      let alt_boundary = boundary <> "_alt"

      let b =
        builder
        |> string_tree.append(
          "Content-Type: multipart/mixed; boundary=\""
          <> mixed_boundary
          <> "\"\r\n\r\n",
        )

      // Add text/html body part
      let b = case text_opt, html_opt {
        Some(text), Some(html) ->
          b
          |> string_tree.append("--" <> mixed_boundary <> "\r\n")
          |> string_tree.append(
            "Content-Type: multipart/alternative; boundary=\""
            <> alt_boundary
            <> "\"\r\n\r\n",
          )
          |> string_tree.append("--" <> alt_boundary <> "\r\n")
          |> string_tree.append(
            "Content-Type: text/plain; charset=utf-8\r\n\r\n",
          )
          |> string_tree.append(text <> "\r\n\r\n")
          |> string_tree.append("--" <> alt_boundary <> "\r\n")
          |> string_tree.append(
            "Content-Type: text/html; charset=utf-8\r\n\r\n",
          )
          |> string_tree.append(html <> "\r\n\r\n")
          |> string_tree.append("--" <> alt_boundary <> "--\r\n")

        Some(text), None ->
          b
          |> string_tree.append("--" <> mixed_boundary <> "\r\n")
          |> string_tree.append(
            "Content-Type: text/plain; charset=utf-8\r\n\r\n",
          )
          |> string_tree.append(text <> "\r\n\r\n")

        None, Some(html) ->
          b
          |> string_tree.append("--" <> mixed_boundary <> "\r\n")
          |> string_tree.append(
            "Content-Type: text/html; charset=utf-8\r\n\r\n",
          )
          |> string_tree.append(html <> "\r\n\r\n")

        None, None -> b
      }

      // Add attachments
      let b =
        list.fold(message.attachments, b, fn(builder, att) {
          let disposition = case att.inline {
            True -> "inline"
            False -> "attachment"
          }
          let ct = content_type_to_string(att.content_type)

          builder
          |> string_tree.append("--" <> mixed_boundary <> "\r\n")
          |> string_tree.append(
            "Content-Type: "
            <> ct
            <> "; name=\""
            <> att.filename
            <> "\"\r\n",
          )
          |> string_tree.append("Content-Transfer-Encoding: base64\r\n")
          |> string_tree.append(
            "Content-Disposition: "
            <> disposition
            <> "; filename=\""
            <> att.filename
            <> "\"\r\n",
          )
          |> string_tree.append(
            case att.content_id {
              Some(cid) -> "Content-ID: <" <> cid <> ">\r\n"
              None -> ""
            },
          )
          |> string_tree.append("\r\n")
          |> string_tree.append(bit_array.base64_encode(att.data, True) <> "\r\n\r\n")
        })

      b
      |> string_tree.append("--" <> mixed_boundary <> "--\r\n")
    }

    // No body at all
    None, None, True ->
      builder
      |> string_tree.append(
        "Content-Type: text/plain; charset=utf-8\r\n\r\n",
      )
  }

  string_tree.to_string(builder)
}
