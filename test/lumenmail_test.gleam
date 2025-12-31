import gleeunit
import gleeunit/should
import lumenmail/auth
import lumenmail/message
import lumenmail/types.{AuthCramMd5, AuthLogin, AuthPlain, AuthXOAuth2, Plain}

pub fn main() -> Nil {
  gleeunit.main()
}

// Message Builder Tests

pub fn message_new_test() {
  let msg = message.new()
  should.be_none(msg.from)
  should.be_none(msg.subject)
  should.equal(msg.to, [])
}

pub fn message_from_email_test() {
  let msg =
    message.new()
    |> message.from_email("sender@example.com")

  should.be_some(msg.from)
  let assert option.Some(addr) = msg.from
  should.equal(addr.email, "sender@example.com")
  should.be_none(addr.name)
}

pub fn message_from_name_email_test() {
  let msg =
    message.new()
    |> message.from_name_email("John Doe", "john@example.com")

  should.be_some(msg.from)
  let assert option.Some(addr) = msg.from
  should.equal(addr.email, "john@example.com")
  should.be_some(addr.name)
}

pub fn message_to_email_test() {
  let msg =
    message.new()
    |> message.to_email("recipient1@example.com")
    |> message.to_email("recipient2@example.com")

  should.equal(list.length(msg.to), 2)
}

pub fn message_cc_bcc_test() {
  let msg =
    message.new()
    |> message.cc_email("cc@example.com")
    |> message.bcc_email("bcc@example.com")

  should.equal(list.length(msg.cc), 1)
  should.equal(list.length(msg.bcc), 1)
}

pub fn message_subject_test() {
  let msg =
    message.new()
    |> message.subject("Test Subject")

  should.be_some(msg.subject)
  let assert option.Some(subj) = msg.subject
  should.equal(subj, "Test Subject")
}

pub fn message_body_test() {
  let msg =
    message.new()
    |> message.text_body("Plain text content")
    |> message.html_body("<h1>HTML content</h1>")

  should.be_some(msg.text_body)
  should.be_some(msg.html_body)
}

pub fn message_all_recipients_test() {
  let msg =
    message.new()
    |> message.to_email("to@example.com")
    |> message.cc_email("cc@example.com")
    |> message.bcc_email("bcc@example.com")

  let recipients = message.all_recipients(msg)
  should.equal(list.length(recipients), 3)
}

pub fn message_format_address_test() {
  let addr1 = types.address("test@example.com")
  should.equal(message.format_address(addr1), "test@example.com")

  let addr2 = types.address_with_name("John Doe", "john@example.com")
  should.equal(message.format_address(addr2), "\"John Doe\" <john@example.com>")
}

pub fn message_build_simple_test() {
  let msg =
    message.new()
    |> message.from_email("sender@example.com")
    |> message.to_email("recipient@example.com")
    |> message.subject("Test")
    |> message.text_body("Hello, World!")

  let result = message.build(msg)
  should.be_ok(result)

  let assert Ok(content) = result
  should.be_true(string.contains(content, "From: sender@example.com"))
  should.be_true(string.contains(content, "To: recipient@example.com"))
  should.be_true(string.contains(content, "Subject: Test"))
  should.be_true(string.contains(content, "Hello, World!"))
}

pub fn message_build_no_from_test() {
  let msg =
    message.new()
    |> message.to_email("recipient@example.com")
    |> message.subject("Test")

  let result = message.build(msg)
  should.be_error(result)
}

pub fn message_build_no_recipients_test() {
  let msg =
    message.new()
    |> message.from_email("sender@example.com")
    |> message.subject("Test")

  let result = message.build(msg)
  should.be_error(result)
}

// Authentication Tests

pub fn auth_encode_plain_test() {
  let creds = Plain("user@example.com", "password123")
  let encoded = auth.encode_plain(creds)

  // The encoding should be base64 of "\0user@example.com\0password123"
  should.be_true(string.length(encoded) > 0)
}

pub fn auth_encode_login_test() {
  let creds = Plain("testuser", "testpass")

  let username = auth.encode_login_username(creds)
  let password = auth.encode_login_password(creds)

  // Base64 of "testuser" and "testpass"
  should.be_true(string.length(username) > 0)
  should.be_true(string.length(password) > 0)
}

pub fn auth_mechanism_to_string_test() {
  should.equal(auth.mechanism_to_string(AuthPlain), "PLAIN")
  should.equal(auth.mechanism_to_string(AuthLogin), "LOGIN")
  should.equal(auth.mechanism_to_string(AuthCramMd5), "CRAM-MD5")
  should.equal(auth.mechanism_to_string(AuthXOAuth2), "XOAUTH2")
}

pub fn auth_parse_mechanism_test() {
  should.equal(auth.parse_mechanism("PLAIN"), Ok(AuthPlain))
  should.equal(auth.parse_mechanism("plain"), Ok(AuthPlain))
  should.equal(auth.parse_mechanism("LOGIN"), Ok(AuthLogin))
  should.equal(auth.parse_mechanism("CRAM-MD5"), Ok(AuthCramMd5))
  should.equal(auth.parse_mechanism("XOAUTH2"), Ok(AuthXOAuth2))
  should.be_error(auth.parse_mechanism("UNKNOWN"))
}

pub fn auth_select_best_mechanism_test() {
  let creds = Plain("user", "pass")
  let available = [AuthPlain, AuthLogin]

  let result = auth.select_best_mechanism(available, creds)
  // Should prefer PLAIN over LOGIN for Plain credentials
  should.equal(result, Ok(AuthPlain))
}

pub fn auth_select_cram_md5_when_available_test() {
  let creds = Plain("user", "pass")
  let available = [AuthLogin, AuthCramMd5, AuthPlain]

  let result = auth.select_best_mechanism(available, creds)
  // Should prefer CRAM-MD5 as most secure for Plain credentials
  should.equal(result, Ok(AuthCramMd5))
}

// Types Tests

pub fn types_address_test() {
  let addr = types.address("test@example.com")
  should.equal(addr.email, "test@example.com")
  should.be_none(addr.name)
}

pub fn types_address_with_name_test() {
  let addr = types.address_with_name("Test User", "test@example.com")
  should.equal(addr.email, "test@example.com")
  should.be_some(addr.name)
  let assert option.Some(name) = addr.name
  should.equal(name, "Test User")
}

pub fn types_empty_capabilities_test() {
  let caps = types.empty_capabilities()
  should.be_false(caps.starttls)
  should.be_false(caps.eight_bit_mime)
  should.be_false(caps.pipelining)
  should.equal(caps.size, 0)
  should.equal(caps.auth_mechanisms, [])
}

// Import necessary modules
import gleam/list
import gleam/option
import gleam/string
