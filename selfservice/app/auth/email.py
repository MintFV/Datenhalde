from __future__ import annotations

import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from typing import Protocol, cast

from flask import current_app, url_for
from itsdangerous import URLSafeTimedSerializer


class EmailUser(Protocol):
    email: str
    display_name: str


def _cfg_str(key: str) -> str:
    config = cast(dict[str, object], current_app.config)
    value = config[key]
    if not isinstance(value, str):
        msg = f"Config key {key!r} must be a string"
        raise TypeError(msg)
    return value


def _cfg_int(key: str, default: int) -> int:
    config = cast(dict[str, object], current_app.config)
    value = config.get(key, default)
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, int):
        return value
    if isinstance(value, str):
        return int(value)

    msg = f"Config key {key!r} must be int/str"
    raise TypeError(msg)


def _get_serializer() -> URLSafeTimedSerializer:
    return URLSafeTimedSerializer(_cfg_str("SECRET_KEY"))


def generate_verification_token(email: str) -> str:
    s = _get_serializer()
    return s.dumps(email, salt="email-verify")


def confirm_verification_token(token: str) -> str:
    s = _get_serializer()
    max_age = _cfg_int("EMAIL_TOKEN_MAX_AGE", 86400)
    return cast(str, s.loads(token, salt="email-verify", max_age=max_age))


def generate_reset_token(email: str) -> str:
    s = _get_serializer()
    return s.dumps(email, salt="password-reset")


def confirm_reset_token(token: str) -> str:
    s = _get_serializer()
    max_age = _cfg_int("RESET_TOKEN_MAX_AGE", 3600)
    return cast(str, s.loads(token, salt="password-reset", max_age=max_age))


def _send_email(to: str, subject: str, html_body: str) -> None:
    """Sendet eine E-Mail über den internen smtp-relay Container."""
    smtp_host = _cfg_str("SMTP_HOST")
    smtp_port = _cfg_int("SMTP_PORT", 25)
    smtp_from = _cfg_str("SMTP_FROM")

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = smtp_from
    msg["To"] = to
    msg.attach(MIMEText(html_body, "html"))

    with smtplib.SMTP(smtp_host, smtp_port) as server:
        server.sendmail(smtp_from, [to], msg.as_string())


def send_verification_email(user: EmailUser) -> None:
    token = generate_verification_token(user.email)
    domain = _cfg_str("DOMAIN")
    verify_path = url_for("auth.verify_email", token=token)
    verify_url = f"https://{domain}{verify_path}"

    html = f'''
    <h2>E-Mail-Adresse bestätigen</h2>
    <p>Hallo {user.display_name},</p>
        <p>
            bitte bestätige deine E-Mail-Adresse,
            indem du auf den folgenden Link klickst:
        </p>
    <p><a href="{verify_url}">{verify_url}</a></p>
    <p>Dieser Link ist 24 Stunden gültig.</p>
        <p>
            Falls du dich nicht registriert hast,
            kannst du diese E-Mail ignorieren.
        </p>
    <br>
    <p>MintFV Selfservice</p>
    '''
    _send_email(user.email, "MintFV – E-Mail-Adresse bestätigen", html)


def send_reset_email(user: EmailUser) -> None:
    token = generate_reset_token(user.email)
    domain = _cfg_str("DOMAIN")
    reset_path = url_for("auth.reset_password", token=token)
    reset_url = f"https://{domain}{reset_path}"

    html = f'''
    <h2>Passwort zurücksetzen</h2>
    <p>Hallo {user.display_name},</p>
    <p>du hast eine Anfrage zum Zurücksetzen deines Passworts gestellt.
       Klicke auf den folgenden Link, um ein neues Passwort zu setzen:</p>
    <p><a href="{reset_url}">{reset_url}</a></p>
    <p>Dieser Link ist 1 Stunde gültig.</p>
        <p>
            Falls du diese Anfrage nicht gestellt hast,
            kannst du diese E-Mail ignorieren.
        </p>
    <br>
    <p>MintFV Selfservice</p>
    '''
    _send_email(user.email, "MintFV – Passwort zurücksetzen", html)
