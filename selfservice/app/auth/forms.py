from flask_wtf import FlaskForm
from wtforms import PasswordField, StringField, SubmitField
from wtforms.validators import DataRequired, Email, EqualTo, Length, ValidationError

from ..models import User


class RegistrationForm(FlaskForm):
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
                min=2, max=100, message="Anzeigename muss zwischen 2 und 100 Zeichen lang sein."
            ),
        ],
    )
    password = PasswordField(
        "Passwort",
        validators=[
            DataRequired("Passwort ist erforderlich."),
            Length(min=8, message="Passwort muss mindestens 8 Zeichen lang sein."),
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

    def validate_email(self, field):
        if User.query.filter_by(email=field.data.lower()).first():
            raise ValidationError("Diese E-Mail-Adresse ist bereits registriert.")


class LoginForm(FlaskForm):
    email = StringField(
        "E-Mail-Adresse",
        validators=[
            DataRequired("E-Mail ist erforderlich."),
            Email("Bitte eine gültige E-Mail-Adresse eingeben."),
        ],
    )
    password = PasswordField("Passwort", validators=[DataRequired("Passwort ist erforderlich.")])
    submit = SubmitField("Anmelden")


class ForgotPasswordForm(FlaskForm):
    email = StringField(
        "E-Mail-Adresse",
        validators=[
            DataRequired("E-Mail ist erforderlich."),
            Email("Bitte eine gültige E-Mail-Adresse eingeben."),
        ],
    )
    submit = SubmitField("Passwort zurücksetzen")


class ResetPasswordForm(FlaskForm):
    password = PasswordField(
        "Neues Passwort",
        validators=[
            DataRequired("Passwort ist erforderlich."),
            Length(min=8, message="Passwort muss mindestens 8 Zeichen lang sein."),
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
