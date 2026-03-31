import logging

from flask import flash, redirect, render_template, request, url_for
from flask_login import current_user, login_required, login_user, logout_user
from itsdangerous import BadSignature, SignatureExpired

from ..extensions import db, limiter
from ..models import User
from . import bp
from .email import (
    confirm_reset_token,
    confirm_verification_token,
    send_reset_email,
    send_verification_email,
)
from .forms import (
    ChangePasswordForm,
    ForgotPasswordForm,
    LoginForm,
    RegistrationForm,
    ResendVerificationForm,
    ResetPasswordForm,
)

logger = logging.getLogger(__name__)


@bp.route("/")
def index():
    if current_user.is_authenticated:
        return redirect(url_for("dashboard.overview"))
    return redirect(url_for("auth.login"))


@bp.route("/registrieren", methods=["GET", "POST"])
@limiter.limit("3/hour")
def register():
    if current_user.is_authenticated:
        return redirect(url_for("dashboard.overview"))

    form = RegistrationForm()
    if form.validate_on_submit():
        user = User(
            email=form.email.data.lower().strip(),
            display_name=form.display_name.data.strip(),
        )
        user.set_password(form.password.data)
        db.session.add(user)
        db.session.commit()

        try:
            send_verification_email(user)
            flash(
                "Registrierung erfolgreich! Bitte prüfe deine E-Mails und bestätige deine Adresse.",
                "success",
            )
        except Exception:
            logger.exception("Verifikations-E-Mail konnte nicht gesendet werden")
            flash(
                "Registrierung erfolgreich, aber die Verifikations-E-Mail "
                "konnte nicht gesendet werden. Bitte kontaktiere den Administrator.",
                "warning",
            )

        return redirect(url_for("auth.login"))

    return render_template("auth/register.html", form=form)


@bp.route("/anmelden", methods=["GET", "POST"])
@limiter.limit("5/minute")
def login():
    if current_user.is_authenticated:
        return redirect(url_for("dashboard.overview"))

    form = LoginForm()
    if form.validate_on_submit():
        user = User.query.filter_by(email=form.email.data.lower().strip()).first()
        if user and user.check_password(form.password.data):
            if not user.email_verified:
                flash("Bitte bestätige zuerst deine E-Mail-Adresse.", "warning")
                return render_template("auth/login.html", form=form)
            login_user(user)
            next_page = request.args.get("next")
            # Nur relative URLs zulassen (Open Redirect verhindern)
            if next_page and not next_page.startswith("/"):
                next_page = None
            return redirect(next_page or url_for("dashboard.overview"))
        flash("E-Mail oder Passwort ist falsch.", "danger")

    return render_template("auth/login.html", form=form)


@bp.route("/abmelden")
@login_required
def logout():
    logout_user()
    flash("Du wurdest abgemeldet.", "info")
    return redirect(url_for("auth.login"))


@bp.route("/email-bestaetigen/<token>")
def verify_email(token):
    try:
        email = confirm_verification_token(token)
    except SignatureExpired:
        flash("Der Bestätigungslink ist abgelaufen. Bitte registriere dich erneut.", "danger")
        return redirect(url_for("auth.login"))
    except BadSignature:
        flash("Ungültiger Bestätigungslink.", "danger")
        return redirect(url_for("auth.login"))

    user = User.query.filter_by(email=email).first()
    if not user:
        flash("Benutzer nicht gefunden.", "danger")
        return redirect(url_for("auth.login"))

    if user.email_verified:
        flash("E-Mail-Adresse wurde bereits bestätigt.", "info")
    else:
        user.email_verified = True
        db.session.commit()
        flash("E-Mail-Adresse erfolgreich bestätigt! Du kannst dich jetzt anmelden.", "success")

    return redirect(url_for("auth.login"))


@bp.route("/passwort-vergessen", methods=["GET", "POST"])
@limiter.limit("3/hour")
def forgot_password():
    if current_user.is_authenticated:
        return redirect(url_for("dashboard.overview"))

    form = ForgotPasswordForm()
    if form.validate_on_submit():
        user = User.query.filter_by(email=form.email.data.lower().strip()).first()
        # Immer gleiche Nachricht anzeigen (Enumeration verhindern)
        if user and user.email_verified:
            try:
                send_reset_email(user)
            except Exception:
                logger.exception("Reset-E-Mail konnte nicht gesendet werden")
        flash(
            "Falls ein Konto mit dieser E-Mail existiert, "
            "wurde ein Link zum Zurücksetzen gesendet.",
            "info",
        )
        return redirect(url_for("auth.login"))

    return render_template("auth/forgot_password.html", form=form)


@bp.route("/passwort-zuruecksetzen/<token>", methods=["GET", "POST"])
def reset_password(token):
    if current_user.is_authenticated:
        return redirect(url_for("dashboard.overview"))

    try:
        email = confirm_reset_token(token)
    except SignatureExpired:
        flash("Der Reset-Link ist abgelaufen. Bitte fordere einen neuen an.", "danger")
        return redirect(url_for("auth.forgot_password"))
    except BadSignature:
        flash("Ungültiger Reset-Link.", "danger")
        return redirect(url_for("auth.login"))

    user = User.query.filter_by(email=email).first()
    if not user:
        flash("Benutzer nicht gefunden.", "danger")
        return redirect(url_for("auth.login"))

    form = ResetPasswordForm()
    if form.validate_on_submit():
        user.set_password(form.password.data)
        db.session.commit()
        flash("Passwort erfolgreich geändert! Du kannst dich jetzt anmelden.", "success")
        return redirect(url_for("auth.login"))

    return render_template("auth/reset_password.html", form=form)


@bp.route("/verifizierung-erneut-senden", methods=["GET", "POST"])
@limiter.limit("3/hour")
def resend_verification():
    if current_user.is_authenticated:
        return redirect(url_for("dashboard.overview"))

    form = ResendVerificationForm()
    if form.validate_on_submit():
        user = User.query.filter_by(email=form.email.data.lower().strip()).first()
        # Immer gleiche Nachricht (Enumeration verhindern)
        if user and not user.email_verified:
            try:
                send_verification_email(user)
            except Exception:
                logger.exception(
                    "Verifikations-E-Mail konnte nicht erneut gesendet werden"
                )
        flash(
            "Falls ein Konto mit dieser E-Mail existiert und noch nicht bestätigt wurde, "
            "wurde eine neue Bestätigungs-E-Mail gesendet.",
            "info",
        )
        return redirect(url_for("auth.login"))

    return render_template("auth/resend_verification.html", form=form)


@bp.route("/passwort-aendern", methods=["GET", "POST"])
@login_required
@limiter.limit("5/hour")
def change_password():
    form = ChangePasswordForm()
    if form.validate_on_submit():
        if not current_user.check_password(form.current_password.data):
            flash("Aktuelles Passwort ist falsch.", "danger")
            return render_template("auth/change_password.html", form=form)
        current_user.set_password(form.new_password.data)
        db.session.commit()
        flash("Passwort erfolgreich geändert.", "success")
        return redirect(url_for("dashboard.overview"))

    return render_template("auth/change_password.html", form=form)
