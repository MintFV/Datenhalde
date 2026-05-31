from __future__ import annotations

from typing import Any, cast

from flask_wtf import FlaskForm
from wtforms import PasswordField, StringField, SubmitField
from wtforms.validators import (
    DataRequired,
    Email,
    EqualTo,
    Length,
    ValidationError,
)

from ..models import User


class TypedFlaskForm(FlaskForm):
    def validate_on_submit(
        self, extra_validators: object | None = None
    ) -> bool:
        base_form = cast(Any, super())
        return bool(
            base_form.validate_on_submit(extra_validators=extra_validators)
        )


def _field_str(value: object | None) -> str:
    return value if isinstance(value, str) else ""


class RegistrationForm(TypedFlaskForm):
    email = StringField(
        "E-Mail-Adresse",
        validators=[
            DataRequired("E-Mail ist erforderlich."),
            Email("Bitte eine gültige E-Mail-Adresse eingeben."),
            Length(max=255),
        ],
    )
    display_name = StringField(
        "Anzeigename",
        validators=[
            DataRequired("Anzeigename ist erforderlich."),
            Length(
                min=2,
                max=100,
                message=(
                    "Anzeigename muss zwischen 2 und 100 Zeichen lang sein."
                ),
            ),
        ],
    )
    password = PasswordField(
        "Passwort",
        validators=[
            DataRequired("Passwort ist erforderlich."),
            Length(
                min=8,
                message="Passwort muss mindestens 8 Zeichen lang sein.",
            ),
        ],
    )
    password_confirm = PasswordField(
        "Passwort bestätigen",
        validators=[
            DataRequired("Bitte Passwort bestätigen."),
            EqualTo("password", message="Passwörter stimmen nicht überein."),
        ],
    )
    submit = SubmitField("Registrieren")

    def validate_email(self, field: StringField) -> None:
        email = _field_str(field.data).lower()
        if User.query.filter_by(email=email).first():
            raise ValidationError(
                "Diese E-Mail-Adresse ist bereits registriert."
            )


class LoginForm(TypedFlaskForm):
    email = StringField(
        "E-Mail-Adresse",
        validators=[
            DataRequired("E-Mail ist erforderlich."),
            Email("Bitte eine gültige E-Mail-Adresse eingeben."),
        ],
    )
    password = PasswordField(
        "Passwort",
        validators=[DataRequired("Passwort ist erforderlich.")],
    )
    submit = SubmitField("Anmelden")


class ForgotPasswordForm(TypedFlaskForm):
    email = StringField(
        "E-Mail-Adresse",
        validators=[
            DataRequired("E-Mail ist erforderlich."),
            Email("Bitte eine gültige E-Mail-Adresse eingeben."),
        ],
    )
    submit = SubmitField("Passwort zurücksetzen")


class ResetPasswordForm(TypedFlaskForm):
    password = PasswordField(
        "Neues Passwort",
        validators=[
            DataRequired("Passwort ist erforderlich."),
            Length(
                min=8,
                message="Passwort muss mindestens 8 Zeichen lang sein.",
            ),
        ],
    )
    password_confirm = PasswordField(
        "Passwort bestätigen",
        validators=[
            DataRequired("Bitte Passwort bestätigen."),
            EqualTo("password", message="Passwörter stimmen nicht überein."),
        ],
    )
    submit = SubmitField("Passwort setzen")


class ResendVerificationForm(TypedFlaskForm):
    email = StringField(
        "E-Mail-Adresse",
        validators=[
            DataRequired("E-Mail ist erforderlich."),
            Email("Bitte eine gültige E-Mail-Adresse eingeben."),
        ],
    )
    submit = SubmitField("Bestätigungs-E-Mail erneut senden")


class ChangePasswordForm(TypedFlaskForm):
    current_password = PasswordField(
        "Aktuelles Passwort",
        validators=[DataRequired("Aktuelles Passwort ist erforderlich.")],
    )
    new_password = PasswordField(
        "Neues Passwort",
        validators=[
            DataRequired("Neues Passwort ist erforderlich."),
            Length(
                min=8,
                message="Passwort muss mindestens 8 Zeichen lang sein.",
            ),
        ],
    )
    new_password_confirm = PasswordField(
        "Neues Passwort bestätigen",
        validators=[
            DataRequired("Bitte neues Passwort bestätigen."),
            EqualTo(
                "new_password",
                message="Passwörter stimmen nicht überein.",
            ),
        ],
    )
    submit = SubmitField("Passwort ändern")
