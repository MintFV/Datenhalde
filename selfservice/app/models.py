from datetime import UTC, datetime

from werkzeug.security import check_password_hash, generate_password_hash

from .extensions import db


class User(db.Model):  # type: ignore[name-defined]
    __tablename__ = "users"

    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(255), unique=True, nullable=False, index=True)
    password_hash = db.Column(db.String(255), nullable=False)
    display_name = db.Column(db.String(100), nullable=False)
    role = db.Column(
        db.String(20),
        nullable=False,
        default="user",  # 'admin' oder 'user'
    )
    email_verified = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(UTC))

    # Beziehung zu Tenant
    tenant_id = db.Column(
        db.Integer,
        db.ForeignKey("tenants.id"),
        nullable=True,
    )
    tenant = db.relationship("Tenant", backref=db.backref("users", lazy=True))

    def set_password(self, password: str) -> None:
        self.password_hash = generate_password_hash(password)

    def check_password(self, password: str) -> bool:
        return check_password_hash(self.password_hash, password)

    @property
    def is_authenticated(self) -> bool:
        return True

    @property
    def is_active(self) -> bool:
        return True

    @property
    def is_anonymous(self) -> bool:
        return False

    def get_id(self) -> str:
        return "" if self.id is None else str(self.id)


class Tenant(db.Model):  # type: ignore[name-defined]
    __tablename__ = "tenants"

    id = db.Column(db.Integer, primary_key=True)
    tenant_id = db.Column(
        db.String(100),
        unique=True,
        nullable=False,
        index=True,
    )
    name = db.Column(db.String(200), nullable=False)
    school_type = db.Column(db.String(50), nullable=True)
    bundesland = db.Column(db.String(5), nullable=True)
    city = db.Column(db.String(100), nullable=True)
    contact_email = db.Column(db.String(255), nullable=True)
    lat = db.Column(db.Float, nullable=True)
    lon = db.Column(db.Float, nullable=True)
    status = db.Column(
        db.String(20),
        nullable=False,
        default="active",  # active / suspended
    )
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(UTC))

    mqtt_accounts = db.relationship(
        "MqttAccount",
        backref="tenant",
        lazy=True,
        cascade="all, delete-orphan",
    )
    devices = db.relationship(
        "Device",
        backref="tenant",
        lazy=True,
        cascade="all, delete-orphan",
    )


class MqttAccount(db.Model):  # type: ignore[name-defined]
    __tablename__ = "mqtt_accounts"

    id = db.Column(db.Integer, primary_key=True)
    tenant_id = db.Column(
        db.Integer,
        db.ForeignKey("tenants.id"),
        nullable=False,
    )
    username = db.Column(
        db.String(100),
        unique=True,
        nullable=False,
        index=True,
    )
    role = db.Column(db.String(20), nullable=False)  # admin / sensor / nodered
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(UTC))


class Device(db.Model):  # type: ignore[name-defined]
    __tablename__ = "devices"

    id = db.Column(db.Integer, primary_key=True)
    tenant_id = db.Column(
        db.Integer,
        db.ForeignKey("tenants.id"),
        nullable=False,
    )
    device_id = db.Column(db.String(100), nullable=False)
    device_type = db.Column(
        db.String(20),
        nullable=False,  # tasmota / rpi / telegraf
    )
    description = db.Column(db.String(200), nullable=True)
    created_at = db.Column(db.DateTime, default=lambda: datetime.now(UTC))

    mqtt_account_id = db.Column(
        db.Integer,
        db.ForeignKey("mqtt_accounts.id"),
        nullable=True,
    )
    mqtt_account = db.relationship(
        "MqttAccount",
        backref="device",
        uselist=False,
    )
