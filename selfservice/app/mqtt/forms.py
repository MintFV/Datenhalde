from flask_wtf import FlaskForm
from wtforms import PasswordField, SelectField, StringField, SubmitField
from wtforms.validators import DataRequired, Length, Regexp


class CreateMqttAccountForm(FlaskForm):
    username = StringField(
        "Benutzername",
        validators=[
            DataRequired("Benutzername ist erforderlich."),
            Length(
                min=3,
                max=80,
                message=("Benutzername muss zwischen 3 und 80 Zeichen lang sein."),
            ),
            Regexp(
                r"^[a-zA-Z0-9._-]+$",
                message=("Nur Buchstaben, Zahlen, Punkt, Unterstrich und Bindestrich erlaubt."),
            ),
        ],
    )
    role = SelectField(
        "Rolle",
        choices=[
            ("admin", "Admin (Lese-/Schreibzugriff auf alle Tenant-Topics)"),
            ("sensor", "Sensor (Schreibzugriff auf Geräte-Topics)"),
            ("nodered", "Node-RED (Lesezugriff auf alle Tenant-Topics)"),
        ],
        validators=[DataRequired()],
    )
    device_id = SelectField(
        "Gerät (nur für Sensor)",
        choices=[("", "— keines —")],
        validators=[],
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
    submit = SubmitField("MQTT-Account erstellen")


class ChangeMqttPasswordForm(FlaskForm):
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
    submit = SubmitField("Passwort ändern")


class DeleteMqttAccountForm(FlaskForm):
    submit = SubmitField("Account löschen")
