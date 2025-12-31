# LumenMail Examples

This folder contains example scripts for testing SMTP relay functionality.

## smtp_relay_test.gleam

A complete test script that reads configuration from environment variables.

### Setup

```bash
# Required environment variables
export SMTP_SENDER_EMAIL="notifications@gmail.com"
export SMTP_APP_PASSWORD="abcd efgh ijkl mnop"
export SMTP_RECIPIENT="recipient@example.com"

# Optional environment variables
export SMTP_SERVER="smtp.gmail.com"      # Default: smtp.gmail.com
export SMTP_PORT="587"                    # Default: 587
export SMTP_SENDER_NAME="My App"          # Default: "Test Sender"
```

### Running

```bash
gleam run -m examples/smtp_relay_test
```

### Gmail Setup

To use Gmail as your SMTP relay:

1. Enable 2-Factor Authentication on your Google account
2. Go to https://myaccount.google.com/apppasswords
3. Generate an App Password for "Mail"
4. Use the 16-character password (with or without spaces)

```bash
export SMTP_SENDER_EMAIL="your.email@gmail.com"
export SMTP_APP_PASSWORD="xxxx xxxx xxxx xxxx"
export SMTP_SERVER="smtp.gmail.com"
export SMTP_PORT="587"
export SMTP_RECIPIENT="test@example.com"

gleam run -m examples/smtp_relay_test
```

## gmail_test.gleam

A simpler example with hardcoded configuration values. Edit the constants in the file before running:

```gleam
const sender_email = "myapp.notifications@gmail.com"
const app_password = "xxxx xxxx xxxx xxxx"
const smtp_server = "smtp.gmail.com"
const test_recipient = "test.recipient@example.com"
```

Then run:

```bash
gleam run -m examples/gmail_test
```

## Common SMTP Servers

| Provider | Server | Port | Notes |
|----------|--------|------|-------|
| Gmail | smtp.gmail.com | 587 | Requires App Password |
| Outlook/Hotmail | smtp.office365.com | 587 | |
| Yahoo | smtp.mail.yahoo.com | 587 | Requires App Password |
| SendGrid | smtp.sendgrid.net | 587 | Uses API key as password |
| Mailgun | smtp.mailgun.org | 587 | |
| Amazon SES | email-smtp.{region}.amazonaws.com | 587 | |

## Troubleshooting

### Authentication Failed
- For Gmail: Make sure you're using an App Password, not your regular password
- Verify 2FA is enabled on your account
- Check the email address is correct

### Connection Failed
- Verify the SMTP server hostname is correct
- Check your firewall allows outbound connections on port 587
- Try port 465 with implicit TLS if 587 doesn't work

### Connection Timeout
- Check your network connectivity
- Some networks block SMTP ports - try a different network
- Increase timeout with `smtp.timeout(60_000)`
