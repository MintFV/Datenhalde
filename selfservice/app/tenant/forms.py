from flask_wtf import FlaskForm
from wtforms import FloatField, SelectField, StringField, SubmitField
from wtforms.validators import DataRequired, Email, Length, Optional, Regexp

from .service import BUNDESLAENDER, SCHOOL_TYPES


class TenantRequestForm(FlaskForm):
    name = StringField(
        "Name der Schule / Organisation",
        validators=[DataRequired("Name ist erforderlich."), Length(max=200)],
    )
    school_type = SelectField(
        "Schultyp",
        choices=SCHOOL_TYPES,
        validators=[DataRequired()],
    )
    bundesland = SelectField(
        "Bundesland",
        choices=BUNDESLAENDER,
        validators=[DataRequired()],
    )
    city = StringField("Ort", validators=[Optional(), Length(max=100)])
    contact_email = StringField(
        "Kontakt-E-Mail",
        validators=[Optional(), Email(), Length(max=255)],
    )
    lat = FloatField("Breitengrad", validators=[Optional()])
    lon = FloatField("Längengrad", validators=[Optional()])
    submit = SubmitField("Tenant beantragen")


class DeviceForm(FlaskForm):
    device_id = StringField(
        "Geräte-ID",
        validators=[
            DataRequired("Geräte-ID ist erforderlich."),
            Length(min=2, max=100),
            Regexp(
                r"^[a-z0-9-]+$",
                message="Nur Kleinbuchstaben, Zahlen und Bindestriche erlaubt.",
            ),
        ],
    )
    device_type = SelectField(
        "Gerätetyp",
        choices=[
            ("tasmota", "Tasmota (ESP8266/ESP32)"),
            ("rpi", "Raspberry Pi"),
            ("telegraf", "Telegraf / Computer"),
        ],
        validators=[DataRequired()],
    )
    description = StringField(
        "Beschreibung",
        validators=[Optional(), Length(max=200)],
    )
    mqtt_account_id = SelectField(
        "MQTT-Account",
        choices=[("", "— keiner —")],
        validators=[Optional()],
    )
    submit = SubmitField("Speichern")
