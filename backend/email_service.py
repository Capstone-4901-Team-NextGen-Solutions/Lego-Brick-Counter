# email_service.py
#
# Supports three email providers — configure whichever you can sign up for:
#
#   OPTION A — Resend (recommended, easiest signup at resend.com)
#     EMAIL_PROVIDER=resend
#     RESEND_API_KEY=re_E1wCHDAH_B3hvwZv5g2HtpM5fGbTudDRL
#
#   OPTION B — Brevo (brevo.com, formerly Sendinblue)
#     EMAIL_PROVIDER=brevo
#     BREVO_API_KEY=xkeysib-xxxxxxxxxxxx
#
#   OPTION C — Gmail SMTP (no signup needed, uses your Google account)
#     EMAIL_PROVIDER=gmail
#     GMAIL_ADDRESS=youremail@gmail.com
#     GMAIL_APP_PASSWORD=xxxx xxxx xxxx xxxx  (NOT your normal password — see note below)
#
#   Gmail App Password setup:
#     1. Go to myaccount.google.com/security
#     2. Enable 2-Step Verification if not already on
#     3. Search for "App passwords" in the search bar
#     4. Create one named "LEGO App" — Google gives you a 16-character password
#     5. Put that 16-char password (spaces included are fine) in GMAIL_APP_PASSWORD
#
#   Also set in .env for all options:
#     FROM_EMAIL=noreply@yourdomain.com   (or your gmail address for Gmail option)
#     FRONTEND_URL=https://your-deployed-app.web.app

import os
import logging
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

logger = logging.getLogger(__name__)


class EmailService:
    def __init__(self):
        self.provider      = os.getenv('EMAIL_PROVIDER', '').lower()
        self.from_email    = os.getenv('FROM_EMAIL', os.getenv('GMAIL_ADDRESS', 'noreply@legobrickapp.com'))
        self.frontend_url  = os.getenv('FRONTEND_URL', 'http://localhost:5000')

        # Provider-specific config
        self.resend_api_key   = os.getenv('RESEND_API_KEY', '')
        self.brevo_api_key    = os.getenv('BREVO_API_KEY', '')
        self.gmail_address    = os.getenv('GMAIL_ADDRESS', '')
        self.gmail_app_password = os.getenv('GMAIL_APP_PASSWORD', '')

        self.enabled = self._check_enabled()

        if not self.enabled:
            logger.warning(
                "EmailService: No provider configured. Emails will be printed to "
                "the console. Set EMAIL_PROVIDER in .env to enable real delivery.\n"
                "  Options: resend | brevo | gmail"
            )
        else:
            logger.info(f"EmailService: using provider '{self.provider}'")

    def _check_enabled(self) -> bool:
        if self.provider == 'resend' and self.resend_api_key:
            return True
        if self.provider == 'brevo' and self.brevo_api_key:
            return True
        if self.provider == 'gmail' and self.gmail_address and self.gmail_app_password:
            return True
        return False

    # ── Public API ────────────────────────────────────────────────────────────

    def send_verification_email(self, to_email: str, username: str, token: str) -> bool:
        verify_url = f"{self.frontend_url}/verify-email?token={token}"
        subject = "Confirm your LEGO Brick App account"
        html = self._verification_html(username, verify_url)
        return self._send(to_email, subject, html)

    def send_password_reset_email(self, to_email: str, username: str, token: str) -> bool:
        reset_url = f"{self.frontend_url}/reset-password?token={token}"
        subject = "Reset your LEGO Brick App password"
        html = self._reset_html(username, reset_url)
        return self._send(to_email, subject, html)

    def send_welcome_email(self, to_email: str, username: str) -> bool:
        subject = "Your LEGO Brick App account is ready!"
        html = self._welcome_html(username)
        return self._send(to_email, subject, html)

    # ── Routing ───────────────────────────────────────────────────────────────

    def _send(self, to_email: str, subject: str, html: str) -> bool:
        if not self.enabled:
            # Development mode: print to console so you can test without a provider
            logger.info(
                f"\n{'='*60}\n"
                f"[EMAIL NOT SENT — no provider configured]\n"
                f"To:      {to_email}\n"
                f"Subject: {subject}\n"
                f"{'='*60}"
            )
            return True

        try:
            if self.provider == 'resend':
                return self._send_via_resend(to_email, subject, html)
            if self.provider == 'brevo':
                return self._send_via_brevo(to_email, subject, html)
            if self.provider == 'gmail':
                return self._send_via_gmail(to_email, subject, html)
        except Exception as e:
            logger.error(f"Email send failed ({self.provider}): {e}")
            return False

        logger.error(f"Unknown email provider: '{self.provider}'")
        return False

    # ── Provider implementations ──────────────────────────────────────────────

    def _send_via_resend(self, to_email: str, subject: str, html: str) -> bool:
        """Send via Resend API (resend.com — pip install resend)."""
        try:
            import resend
        except ImportError:
            logger.error("Resend package not installed. Run: pip install resend")
            return False

        resend.api_key = self.resend_api_key
        params = {
            "from":    self.from_email,
            "to":      [to_email],
            "subject": subject,
            "html":    html,
        }
        response = resend.Emails.send(params)
        logger.info(f"Resend: sent to {to_email}, id={response.get('id')}")
        return True

    def _send_via_brevo(self, to_email: str, subject: str, html: str) -> bool:
        """Send via Brevo API (brevo.com — pip install sib-api-v3-sdk)."""
        try:
            import sib_api_v3_sdk
            from sib_api_v3_sdk.rest import ApiException
        except ImportError:
            logger.error("Brevo package not installed. Run: pip install sib-api-v3-sdk")
            return False

        configuration = sib_api_v3_sdk.Configuration()
        configuration.api_key['api-key'] = self.brevo_api_key
        api = sib_api_v3_sdk.TransactionalEmailsApi(
            sib_api_v3_sdk.ApiClient(configuration)
        )
        send_smtp_email = sib_api_v3_sdk.SendSmtpEmail(
            sender={"email": self.from_email},
            to=[{"email": to_email}],
            subject=subject,
            html_content=html,
        )
        api.send_transac_email(send_smtp_email)
        logger.info(f"Brevo: sent to {to_email}")
        return True

    def _send_via_gmail(self, to_email: str, subject: str, html: str) -> bool:
        """
        Send via Gmail SMTP using an App Password.
        No external library needed — uses Python's built-in smtplib.
        """
        msg = MIMEMultipart('alternative')
        msg['From']    = self.gmail_address
        msg['To']      = to_email
        msg['Subject'] = subject
        msg.attach(MIMEText(html, 'html'))

        # Remove spaces from app password (Google sometimes shows it with spaces)
        password = self.gmail_app_password.replace(' ', '')

        with smtplib.SMTP_SSL('smtp.gmail.com', 465) as smtp:
            smtp.login(self.gmail_address, password)
            smtp.sendmail(self.gmail_address, to_email, msg.as_string())

        logger.info(f"Gmail SMTP: sent to {to_email}")
        return True

    # ── Email HTML templates ───────────────────────────────────────────────────

    def _base_template(self, body_html: str) -> str:
        return f"""
        <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <div style="background:#FFD700;padding:20px;text-align:center;border-radius:8px 8px 0 0;">
                <h1 style="color:#1A1A2E;margin:0;">&#129307; LEGO Brick App</h1>
            </div>
            <div style="background:#f9f9f9;padding:30px;border-radius:0 0 8px 8px;">
                {body_html}
            </div>
            <p style="color:#bbb;font-size:11px;text-align:center;margin-top:16px;">
                You received this email because you have an account with LEGO Brick App.
            </p>
        </div>
        """

    def _verification_html(self, username: str, verify_url: str) -> str:
        body = f"""
        <h2 style="color:#1A1A2E;">Welcome, {username}!</h2>
        <p style="color:#555;font-size:16px;">
            Thanks for registering. Please confirm your email address by clicking below.
        </p>
        <div style="text-align:center;margin:30px 0;">
            <a href="{verify_url}"
               style="background:#D01012;color:white;padding:14px 28px;
                      text-decoration:none;border-radius:8px;font-size:16px;font-weight:bold;">
                Confirm Email Address
            </a>
        </div>
        <p style="color:#999;font-size:13px;">
            This link expires in 24 hours. If you didn't create this account, ignore this email.
        </p>
        <p style="color:#bbb;font-size:12px;">
            Or copy: <a href="{verify_url}" style="color:#006DB7;">{verify_url}</a>
        </p>
        """
        return self._base_template(body)

    def _reset_html(self, username: str, reset_url: str) -> str:
        body = f"""
        <h2 style="color:#1A1A2E;">Password Reset Request</h2>
        <p style="color:#555;font-size:16px;">
            Hi {username}, we received a request to reset your password.
        </p>
        <div style="text-align:center;margin:30px 0;">
            <a href="{reset_url}"
               style="background:#D01012;color:white;padding:14px 28px;
                      text-decoration:none;border-radius:8px;font-size:16px;font-weight:bold;">
                Reset My Password
            </a>
        </div>
        <p style="color:#999;font-size:13px;">
            This link expires in 1 hour. If you didn't request this, ignore this email.
        </p>
        <p style="color:#bbb;font-size:12px;">
            Or copy: <a href="{reset_url}" style="color:#006DB7;">{reset_url}</a>
        </p>
        """
        return self._base_template(body)

    def _welcome_html(self, username: str) -> str:
        body = f"""
        <h2 style="color:#1A1A2E;">You're all set, {username}! &#127881;</h2>
        <p style="color:#555;font-size:16px;">Your account has been verified. Here's what you can do:</p>
        <ul style="color:#555;font-size:15px;line-height:2;">
            <li>&#128247; <strong>Scan bricks</strong> — photograph your LEGO pieces</li>
            <li>&#128230; <strong>Build inventory</strong> — track every brick you own</li>
            <li>&#128296; <strong>Find sets</strong> — see what you can build right now</li>
        </ul>
        <div style="text-align:center;margin:30px 0;">
            <a href="{self.frontend_url}"
               style="background:#006DB7;color:white;padding:14px 28px;
                      text-decoration:none;border-radius:8px;font-size:16px;font-weight:bold;">
                Open the App
            </a>
        </div>
        """
        return self._base_template(body)


# Module-level singleton — import anywhere in app:
#   from email_service import email_service
email_service = EmailService()