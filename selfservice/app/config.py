import os


class Config:
    SECRET_KEY = os.environ.get("SELFSERVICE_SECRET_KEY") or "change-me-in-production"
    SQLALCHEMY_DATABASE_URI = "sqlite:////app/data/selfservice.db"
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    # Domain
    DOMAIN = os.environ.get("DOMAIN", "localhost")

    # E-Mail (Flask-Mailman, interner smtp-relay Container)
    MAIL_SERVER = os.environ.get("SMTP_HOST", "smtp-relay")
    MAIL_PORT = int(os.environ.get("SMTP_PORT", "8025"))
    MAIL_USE_TLS = False
    MAIL_USE_SSL = False
    MAIL_DEFAULT_SENDER = os.environ.get(
        "SMTP_FROM", f"noreply@{os.environ.get('DOMAIN', 'localhost')}"
    )

    # Legacy-Zugriff (für Abwärtskompatibilität)
    SMTP_HOST = os.environ.get("SMTP_HOST", "smtp-relay")
    SMTP_PORT = int(os.environ.get("SMTP_PORT", "8025"))
    SMTP_FROM = os.environ.get("SMTP_FROM", f"noreply@{os.environ.get('DOMAIN', 'localhost')}")

    # Mosquitto-Pfade (Volume-Mounts)
    MOSQUITTO_PASSWD_FILE = os.environ.get(
        "MOSQUITTO_PASSWD_FILE", "/mosquitto/config/mosquitto.passwd"
    )
    MOSQUITTO_ACL_FILE = os.environ.get("MOSQUITTO_ACL_FILE", "/mosquitto/config/mosquitto.acl")
    MOSQUITTO_RELOAD_DIR = os.environ.get("MOSQUITTO_RELOAD_DIR", "/app/reload")

    # Token-Gültigkeit
    EMAIL_TOKEN_MAX_AGE = 86400  # 24 Stunden (Verifikation)
    RESET_TOKEN_MAX_AGE = 3600  # 1 Stunde (Passwort-Reset)

    # Application Root
    APPLICATION_ROOT = "/selfservice"
