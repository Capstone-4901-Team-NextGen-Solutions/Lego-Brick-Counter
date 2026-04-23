# email_service.py
#
# Supports Gmail SMTP (no signup) and Resend (resend.com).
#
# Gmail setup (recommended — no new account needed):
#   EMAIL_PROVIDER=gmail
#   GMAIL_ADDRESS=youremail@gmail.com
#   GMAIL_APP_PASSWORD=xxxx xxxx xxxx xxxx
#   FROM_EMAIL=youremail@gmail.com
#
#   How to get a Gmail App Password:
#     1. myaccount.google.com/security
#     2. Enable 2-Step Verification
#     3. Search "App passwords" → create one named "LEGO App"
#     4. Copy the 16-char password into GMAIL_APP_PASSWORD
#
# Resend setup:
#   EMAIL_PROVIDER=resend
#   RESEND_API_KEY=re_xxxxxxxxxxxx
#   FROM_EMAIL=onboarding@resend.dev   ← use this if no verified domain
#
# Also set:
#   FRONTEND_URL=https://your-firebase-app.web.app

import os
import logging
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

logger = logging.getLogger(__name__)


class EmailService:
    def __init__(self):
        self.provider           = os.getenv('EMAIL_PROVIDER', '').lower().strip()
        self.from_email         = os.getenv('FROM_EMAIL', os.getenv('GMAIL_ADDRESS', ''))
        self.frontend_url       = os.getenv('FRONTEND_URL', 'http://localhost:5000')
        self.resend_api_key     = os.getenv('RESEND_API_KEY', '')
        self.gmail_address      = os.getenv('GMAIL_ADDRESS', '')
        self.gmail_app_password = os.getenv('GMAIL_APP_PASSWORD', '')
        self.enabled            = self._check_enabled()

        if not self.enabled:
            logger.warning(
                "EmailService: No provider configured — emails will only be "
                "printed to the console.\n"
                "  Set EMAIL_PROVIDER=gmail or EMAIL_PROVIDER=resend in your .env"
            )
        else:
            logger.info(f"EmailService: provider='{self.provider}' from='{self.from_email}'")

    def _check_enabled(self) -> bool:
        if self.provider == 'resend' and self.resend_api_key:
            return True
        if self.provider == 'gmail' and self.gmail_address and self.gmail_app_password:
            return True
        return False

    # ── Public API ────────────────────────────────────────────────────────────

    def send_verification_email(self, to_email: str, username: str, token: str) -> bool:
        verify_url = f"{self.frontend_url}/verify-email?token={token}"
        return self._send(
            to_email=to_email,
            subject="Confirm your LEGO Brick App account",
            html=self._verification_html(username, verify_url),
        )

    def send_password_reset_email(self, to_email: str, username: str, token: str) -> bool:
        reset_url = f"{self.frontend_url}/reset-password?token={token}"
        return self._send(
            to_email=to_email,
            subject="Reset your LEGO Brick App password",
            html=self._reset_html(username, reset_url),
        )

    def send_welcome_email(self, to_email: str, username: str) -> bool:
        return self._send(
            to_email=to_email,
            subject="Your LEGO Brick App account is ready!",
            html=self._welcome_html(username),
        )

    # ── Internal routing ──────────────────────────────────────────────────────

    def _send(self, to_email: str, subject: str, html: str) -> bool:
        if not self.enabled:
            logger.info(
                f"\n{'='*60}\n"
                f"[EMAIL — NOT SENT (no provider configured)]\n"
                f"To:      {to_email}\n"
                f"Subject: {subject}\n"
                f"{'='*60}"
            )
            return True

        try:
            if self.provider == 'resend':
                return self._send_resend(to_email, subject, html)
            if self.provider == 'gmail':
                return self._send_gmail(to_email, subject, html)
            logger.error(f"Unknown EMAIL_PROVIDER: '{self.provider}'")
            return False
        except Exception as exc:
            logger.error(f"Email send failed ({self.provider}): {exc}")
            return False

    # ── Resend v2 ─────────────────────────────────────────────────────────────

    def _send_resend(self, to_email: str, subject: str, html: str) -> bool:
        """
        Send via Resend SDK v2.x.

        IMPORTANT: 'from' is a Python reserved word so it MUST be passed
        inside a plain dict — you cannot use it as a keyword argument.
        The v2 SDK accepts the dict directly as the first positional argument.
        """
        try:
            import resend as resend_sdk
        except ImportError:
            logger.error(
                "resend package not installed. "
                "Add 'resend' to requirements.txt and redeploy."
            )
            return False

        resend_sdk.api_key = self.resend_api_key

        params = {
            "from":    self.from_email,   # 'from' must be a dict key, not kwarg
            "to":      [to_email],
            "subject": subject,
            "html":    html,
        }

        response = resend_sdk.Emails.send(params)

        # v2 returns a SendResponse dataclass with an 'id' attribute
        email_id = getattr(response, 'id', None) or str(response)
        logger.info(f"Resend: sent to {to_email}, id={email_id}")
        return True

    # ── Gmail SMTP ────────────────────────────────────────────────────────────

    def _send_gmail(self, to_email: str, subject: str, html: str) -> bool:
        """
        Send via Gmail SMTP with an App Password.
        Uses Python's built-in smtplib — no extra package needed.
        """
        msg            = MIMEMultipart('alternative')
        msg['From']    = self.gmail_address
        msg['To']      = to_email
        msg['Subject'] = subject
        msg.attach(MIMEText(html, 'html'))

        # Google sometimes displays the app password with spaces — strip them
        password = self.gmail_app_password.replace(' ', '')

        with smtplib.SMTP_SSL('smtp.gmail.com', 465) as smtp:
            smtp.login(self.gmail_address, password)
            smtp.sendmail(self.gmail_address, to_email, msg.as_string())

        logger.info(f"Gmail SMTP: sent to {to_email}")
        return True

    # ── HTML templates ────────────────────────────────────────────────────────

    def _base(self, body: str) -> str:
        return f"""
        <div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;">
          <div style="background:#FFD700;padding:20px;text-align:center;
                      border-radius:8px 8px 0 0;">
            <h1 style="color:#1A1A2E;margin:0;">&#129307; LEGO Brick App</h1>
          </div>
          <div style="background:#f9f9f9;padding:30px;border-radius:0 0 8px 8px;">
            {body}
          </div>
          <p style="color:#bbb;font-size:11px;text-align:center;margin-top:16px;">
            You received this because you have a LEGO Brick App account.
          </p>
        </div>"""

    def _verification_html(self, username: str, url: str) -> str:
        return self._base(f"""
          <h2 style="color:#1A1A2E;">Welcome, {username}!</h2>
          <p style="color:#555;font-size:16px;">
            Thanks for registering. Please confirm your email address.
          </p>
          <div style="text-align:center;margin:30px 0;">
            <a href="{url}" style="background:#D01012;color:white;padding:14px 28px;
               text-decoration:none;border-radius:8px;font-size:16px;font-weight:bold;">
              Confirm Email Address
            </a>
          </div>
          <p style="color:#999;font-size:13px;">
            This link expires in 24 hours. If you didn't create this account,
            you can safely ignore this email.
          </p>
          <p style="color:#bbb;font-size:12px;">
            Or copy: <a href="{url}" style="color:#006DB7;">{url}</a>
          </p>""")

    def _reset_html(self, username: str, url: str) -> str:
        return self._base(f"""
          <h2 style="color:#1A1A2E;">Password Reset Request</h2>
          <p style="color:#555;font-size:16px;">
            Hi {username}, we received a request to reset your password.
          </p>
          <div style="text-align:center;margin:30px 0;">
            <a href="{url}" style="background:#D01012;color:white;padding:14px 28px;
               text-decoration:none;border-radius:8px;font-size:16px;font-weight:bold;">
              Reset My Password
            </a>
          </div>
          <p style="color:#999;font-size:13px;">
            This link expires in 1 hour. If you didn't request this,
            you can safely ignore this email.
          </p>
          <p style="color:#bbb;font-size:12px;">
            Or copy: <a href="{url}" style="color:#006DB7;">{url}</a>
          </p>""")

    def _welcome_html(self, username: str) -> str:
        return self._base(f"""
          <h2 style="color:#1A1A2E;">You're all set, {username}! &#127881;</h2>
          <p style="color:#555;font-size:16px;">
            Your account has been verified. Here's what you can do:
          </p>
          <ul style="color:#555;font-size:15px;line-height:2;">
            <li>&#128247; <strong>Scan bricks</strong> — photograph your LEGO pieces</li>
            <li>&#128230; <strong>Build inventory</strong> — track every brick you own</li>
            <li>&#128296; <strong>Find sets</strong> — see what you can build right now</li>
          </ul>
          <div style="text-align:center;margin:30px 0;">
            <a href="{self.frontend_url}" style="background:#006DB7;color:white;
               padding:14px 28px;text-decoration:none;border-radius:8px;
               font-size:16px;font-weight:bold;">
              Open the App
            </a>
          </div>""")


# Module-level singleton
email_service = EmailService()