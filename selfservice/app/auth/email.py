import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from flask import current_app, url_for
from itsdangerous import URLSafeTimedSerializer


def _get_serializer():
    return URLSafeTimedSerializer(current_app.config["SECRET_KEY"])


def generate_verification_token(email):
    s = _get_serializer()
    return s.dumps(email, salt="email-verify")


def confirm_verification_token(token):
    s = _get_serializer()
    max_age = current_app.config.get("EMAIL_TOKEN_MAX_AGE", 86400)
    return s.loads(token, salt="email-verify", max_age=max_age)


def generate_reset_token(email):
    s = _get_serializer()
    return s.dumps(email, salt="password-reset")


def confirm_reset_token(token):
    s = _get_serializer()
    max_age = current_app.config.get("RESET_TOKEN_MAX_AGE", 3600)
    return s.loads(token, salt="password-reset", max_age=max_age)


def _send_email(to, subject, html_body):
    """Sendet eine E-Mail über den internen smtp-relay Container."""
    smtp_host = current_app.config["SMTP_HOST"]
    smtp_port = current_app.config["SMTP_PORT"]
    smtp_from = current_app.config["SMTP_FROM"]

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = smtp_from
    msg["To"] = to
    msg.attach(MIMEText(html_body, "html"))

    with smtplib.SMTP(smtp_host, smtp_port) as server:
        server.sendmail(smtp_from, [to], msg.as_string())


def send_verification_email(user):
    token = generate_verification_token(user.email)
    domain = current_app.config["DOMAIN"]
    verify_url = f"https://{domain}{url_for('auth.verify_email', token=token)}"

    html = f'''
    <h2>E-Mail-Adresse bestätigen</h2>
    <p>Hallo {user.display_name},</p>
    <p>bitte bestätige deine E-Mail-Adresse, indem du auf den folgenden Link klickst:</p>
    <p><a href="{verify_url}">{verify_url}</a></p>
    <p>Dieser Link ist 24 Stunden gültig.</p>
    <p>Falls du dich nicht registriert hast, kannst du diese E-Mail ignorieren.</p>
    <br>
    <p>MintFV Selfservice</p>
    '''
    _send_email(user.email, "MintFV – E-Mail-Adresse bestätigen", html)


def send_reset_email(user):
    token = generate_reset_token(user.email)
    domain = current_app.config["DOMAIN"]
    reset_url = f"https://{domain}{url_for('auth.reset_password', token=token)}"

    html = f'''
    <h2>Passwort zurücksetzen</h2>
    <p>Hallo {user.display_name},</p>
    <p>du hast eine Anfrage zum Zurücksetzen deines Passworts gestellt.
       Klicke auf den folgenden Link, um ein neues Passwort zu setzen:</p>
    <p><a href="{reset_url}">{reset_url}</a></p>
    <p>Dieser Link ist 1 Stunde gültig.</p>
    <p>Falls du diese Anfrage nicht gestellt hast, kannst du diese E-Mail ignorieren.</p>
    <br>
    <p>MintFV Selfservice</p>
    '''
    _send_email(user.email, "MintFV – Passwort zurücksetzen", html)
