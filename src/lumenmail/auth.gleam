//// Authentication module for SMTP.
//// Implements various SMTP authentication mechanisms.

import gleam/bit_array
import gleam/crypto
import gleam/string
import lumenmail/types.{
  type AuthMechanism, type Credentials, AuthCramMd5, AuthLogin, AuthPlain,
  AuthXOAuth2, OAuth2, Plain,
}

/// Encodes credentials for PLAIN authentication.
/// Format: \0username\0password (base64 encoded)
pub fn encode_plain(credentials: Credentials) -> String {
  case credentials {
    Plain(username, password) -> {
      let auth_string = "\u{0000}" <> username <> "\u{0000}" <> password
      base64_encode_string(auth_string)
    }
    OAuth2(username, _) -> {
      // For OAuth2, use PLAIN with empty password (token goes in XOAUTH2)
      let auth_string = "\u{0000}" <> username <> "\u{0000}"
      base64_encode_string(auth_string)
    }
  }
}

/// Encodes the username for LOGIN authentication (first step).
pub fn encode_login_username(credentials: Credentials) -> String {
  case credentials {
    Plain(username, _) -> base64_encode_string(username)
    OAuth2(username, _) -> base64_encode_string(username)
  }
}

/// Encodes the password for LOGIN authentication (second step).
pub fn encode_login_password(credentials: Credentials) -> String {
  case credentials {
    Plain(_, password) -> base64_encode_string(password)
    OAuth2(_, token) -> base64_encode_string(token)
  }
}

/// Generates CRAM-MD5 response from challenge.
/// Challenge is base64 encoded from server.
/// Response format: username HMAC-MD5-digest (base64 encoded)
pub fn encode_cram_md5(credentials: Credentials, challenge: String) -> String {
  case credentials {
    Plain(username, password) -> {
      // Decode the challenge from base64
      let challenge_decoded = base64_decode_string(challenge)

      // Compute HMAC-MD5
      let digest =
        crypto.hmac(
          <<challenge_decoded:utf8>>,
          crypto.Md5,
          <<password:utf8>>,
        )
      let hex_digest = bit_array_to_hex(digest)

      // Response is "username hex_digest"
      let response = username <> " " <> hex_digest
      base64_encode_string(response)
    }
    OAuth2(_, _) -> {
      // OAuth2 doesn't support CRAM-MD5
      ""
    }
  }
}

/// Generates XOAUTH2 authentication string.
/// Format: user=<email>\x01auth=Bearer <token>\x01\x01
pub fn encode_xoauth2(credentials: Credentials) -> String {
  case credentials {
    OAuth2(username, token) -> {
      let auth_string =
        "user="
        <> username
        <> "\u{0001}auth=Bearer "
        <> token
        <> "\u{0001}\u{0001}"
      base64_encode_string(auth_string)
    }
    Plain(username, password) -> {
      // Treat password as token for XOAUTH2
      let auth_string =
        "user="
        <> username
        <> "\u{0001}auth=Bearer "
        <> password
        <> "\u{0001}\u{0001}"
      base64_encode_string(auth_string)
    }
  }
}

/// Selects the best authentication mechanism from available options.
/// Prefers more secure mechanisms.
pub fn select_best_mechanism(
  available: List(AuthMechanism),
  credentials: Credentials,
) -> Result(AuthMechanism, String) {
  // Priority order (most secure first):
  // For OAuth2 credentials: XOAUTH2 > PLAIN > LOGIN
  // For Plain credentials: CRAM-MD5 > PLAIN > LOGIN

  case credentials {
    OAuth2(_, _) -> {
      case list_contains(available, AuthXOAuth2) {
        True -> Ok(AuthXOAuth2)
        False ->
          case list_contains(available, AuthPlain) {
            True -> Ok(AuthPlain)
            False ->
              case list_contains(available, AuthLogin) {
                True -> Ok(AuthLogin)
                False -> Error("No compatible authentication mechanism found")
              }
          }
      }
    }
    Plain(_, _) -> {
      case list_contains(available, AuthCramMd5) {
        True -> Ok(AuthCramMd5)
        False ->
          case list_contains(available, AuthPlain) {
            True -> Ok(AuthPlain)
            False ->
              case list_contains(available, AuthLogin) {
                True -> Ok(AuthLogin)
                False -> Error("No compatible authentication mechanism found")
              }
          }
      }
    }
  }
}

/// Returns the SMTP command name for an auth mechanism.
pub fn mechanism_to_string(mechanism: AuthMechanism) -> String {
  case mechanism {
    AuthPlain -> "PLAIN"
    AuthLogin -> "LOGIN"
    AuthCramMd5 -> "CRAM-MD5"
    AuthXOAuth2 -> "XOAUTH2"
  }
}

/// Parses an auth mechanism string from server.
pub fn parse_mechanism(s: String) -> Result(AuthMechanism, Nil) {
  case string.uppercase(s) {
    "PLAIN" -> Ok(AuthPlain)
    "LOGIN" -> Ok(AuthLogin)
    "CRAM-MD5" -> Ok(AuthCramMd5)
    "XOAUTH2" -> Ok(AuthXOAuth2)
    _ -> Error(Nil)
  }
}

// Helper functions

fn list_contains(list: List(AuthMechanism), item: AuthMechanism) -> Bool {
  case list {
    [] -> False
    [first, ..rest] ->
      case first == item {
        True -> True
        False -> list_contains(rest, item)
      }
  }
}

@external(erlang, "base64", "encode")
fn do_base64_encode(data: BitArray) -> String

@external(erlang, "base64", "decode")
fn do_base64_decode(data: String) -> BitArray

fn base64_encode_string(s: String) -> String {
  do_base64_encode(<<s:utf8>>)
}

fn base64_decode_string(s: String) -> String {
  let decoded = do_base64_decode(s)
  case bit_array.to_string(decoded) {
    Ok(str) -> str
    Error(_) -> ""
  }
}

fn bit_array_to_hex(bits: BitArray) -> String {
  bits
  |> bit_array.base16_encode()
  |> string.lowercase()
}
