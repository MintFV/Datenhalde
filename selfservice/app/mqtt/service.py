"""
MQTT User & ACL Management Service

Portierung der Logik aus manage_mqtt_users.sh nach Python.
Manipuliert mosquitto.passwd und mosquitto.acl direkt und
signalisiert dem mosquitto-reload Sidecar via Touch-Datei.
"""

import base64
import fcntl
import hashlib
import logging
import os
import re
import secrets
import time

from flask import current_app

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Mosquitto-kompatibles Passwort-Hashing (PBKDF2-SHA512)
# Format: $7$101$<base64-salt>$<base64-hash>
# ---------------------------------------------------------------------------


def _generate_mosquitto_hash(password: str) -> str:
    """Erzeugt einen Mosquitto-kompatiblen PBKDF2-SHA512 Hash.

    Mosquitto 2.x nutzt: $7$<iterations>$<base64-salt>$<base64-hash>
    - Algorithmus: PBKDF2 mit SHA-512
    - Iterations: 101 (Mosquitto-Standard)
    - Salt: 12 Bytes zufällig
    """
    iterations = 101
    salt = secrets.token_bytes(12)
    dk = hashlib.pbkdf2_hmac("sha512", password.encode("utf-8"), salt, iterations, dklen=64)
    salt_b64 = base64.b64encode(salt).decode("ascii")
    hash_b64 = base64.b64encode(dk).decode("ascii")
    return f"$7${iterations}${salt_b64}${hash_b64}"


# ---------------------------------------------------------------------------
# Datei-Operationen mit File-Locking
# ---------------------------------------------------------------------------


def _read_file_locked(filepath: str) -> str:
    """Liest eine Datei mit Shared Lock."""
    with open(filepath, encoding="utf-8") as f:
        fcntl.flock(f, fcntl.LOCK_SH)
        try:
            return f.read()
        finally:
            fcntl.flock(f, fcntl.LOCK_UN)


def _write_file_locked(filepath: str, content: str):
    """Schreibt eine Datei mit Exclusive Lock."""
    with open(filepath, "r+", encoding="utf-8") as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        try:
            f.seek(0)
            f.write(content)
            f.truncate()
        finally:
            fcntl.flock(f, fcntl.LOCK_UN)


def _signal_reload():
    """Erzeugt eine Trigger-Datei im Reload-Verzeichnis,
    die vom mosquitto-reload Sidecar erkannt wird."""
    reload_dir = current_app.config["MOSQUITTO_RELOAD_DIR"]
    trigger_file = os.path.join(reload_dir, "reload.trigger")
    with open(trigger_file, "w", encoding="utf-8") as f:
        f.write(str(time.time()))
    logger.info("Mosquitto-Reload signalisiert")


# ---------------------------------------------------------------------------
# Passwort-Datei Verwaltung (mosquitto.passwd)
# ---------------------------------------------------------------------------


def _get_passwd_path() -> str:
    return current_app.config["MOSQUITTO_PASSWD_FILE"]


def _get_acl_path() -> str:
    return current_app.config["MOSQUITTO_ACL_FILE"]


def _ensure_files_exist():
    """Stellt sicher, dass passwd- und ACL-Dateien existieren."""
    for path in [_get_passwd_path(), _get_acl_path()]:
        if not os.path.exists(path):
            with open(path, "w", encoding="utf-8") as f:
                f.write("")


def create_mqtt_user(username: str, password: str) -> bool:
    """Erstellt oder aktualisiert einen MQTT-Benutzer in der passwd-Datei."""
    _ensure_files_exist()
    passwd_path = _get_passwd_path()

    password_hash = _generate_mosquitto_hash(password)
    new_line = f"{username}:{password_hash}"

    content = _read_file_locked(passwd_path)
    lines = content.splitlines()

    # Benutzer aktualisieren oder neu hinzufügen
    updated = False
    for i, line in enumerate(lines):
        if line.startswith(f"{username}:"):
            lines[i] = new_line
            updated = True
            break

    if not updated:
        lines.append(new_line)

    _write_file_locked(passwd_path, "\n".join(lines) + "\n")
    logger.info("MQTT-Benutzer erstellt/aktualisiert: %s", username)
    return True


def delete_mqtt_user(username: str) -> bool:
    """Löscht einen MQTT-Benutzer aus der passwd-Datei."""
    _ensure_files_exist()
    passwd_path = _get_passwd_path()

    content = _read_file_locked(passwd_path)
    lines = content.splitlines()

    new_lines = [line for line in lines if not line.startswith(f"{username}:")]
    if len(new_lines) == len(lines):
        return False  # User nicht gefunden

    _write_file_locked(passwd_path, "\n".join(new_lines) + "\n")
    logger.info("MQTT-Benutzer gelöscht: %s", username)
    return True


def mqtt_user_exists(username: str) -> bool:
    """Prüft ob ein MQTT-Benutzer existiert."""
    _ensure_files_exist()
    content = _read_file_locked(_get_passwd_path())
    return any(line.startswith(f"{username}:") for line in content.splitlines())


def list_mqtt_users() -> list[str]:
    """Gibt eine Liste aller MQTT-Benutzernamen zurück."""
    _ensure_files_exist()
    content = _read_file_locked(_get_passwd_path())
    return [line.split(":")[0] for line in content.splitlines() if ":" in line]


# ---------------------------------------------------------------------------
# ACL-Datei Verwaltung (mosquitto.acl)
# ---------------------------------------------------------------------------


def add_acl_rules(username: str, tenant_id: str, role: str = "admin", device_id: str | None = None):
    """Fügt ACL-Regeln für einen Benutzer hinzu.

    Rollen:
        admin  – readwrite auf umweltbox/{tenant_id}/#
        sensor – write auf umweltbox/{tenant_id}/{device_id}/#
                 read  auf umweltbox/{tenant_id}/cmnd/{device_id}/#
                 read  auf $SYS/broker/version
    """
    _ensure_files_exist()
    acl_path = _get_acl_path()

    content = _read_file_locked(acl_path)

    # Prüfen ob bereits existiert
    if re.search(rf"^user {re.escape(username)}$", content, re.MULTILINE):
        logger.warning("ACL-Eintrag für %s existiert bereits", username)
        return

    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    entry = f"\n# Selfservice: {timestamp}\nuser {username}\n"

    if role == "admin":
        entry += f"topic readwrite umweltbox/{tenant_id}/#\n"
        entry += "topic read $SYS/broker/version\n"
    elif role == "sensor" and device_id:
        entry += f"topic write umweltbox/{tenant_id}/{device_id}/#\n"
        entry += f"topic read umweltbox/{tenant_id}/cmnd/{device_id}/#\n"
        entry += "topic read $SYS/broker/version\n"
    else:
        # Fallback: readwrite auf Tenant-Namespace
        entry += f"topic readwrite umweltbox/{tenant_id}/{username}/#\n"
        entry += "topic read $SYS/broker/version\n"

    _write_file_locked(acl_path, content.rstrip("\n") + "\n" + entry)
    logger.info("ACL-Regeln hinzugefügt für: %s (Rolle: %s)", username, role)


def remove_acl_rules(username: str):
    """Entfernt alle ACL-Regeln für einen Benutzer."""
    _ensure_files_exist()
    acl_path = _get_acl_path()

    content = _read_file_locked(acl_path)
    lines = content.splitlines()

    new_lines: list[str] = []
    skip = False
    for line in lines:
        if line.strip() == f"user {username}":
            # Vorherige Kommentarzeile entfernen falls vom Selfservice
            if new_lines and new_lines[-1].startswith("# Selfservice:"):
                new_lines.pop()
            # Auch Kommentar aus manage_mqtt_users.sh erkennen
            if new_lines and new_lines[-1].startswith("# Added via script:"):
                new_lines.pop()
            skip = True
            continue
        if skip:
            if line.strip().startswith("topic "):
                continue  # Topic-Zeilen überspringen
            skip = False
        new_lines.append(line)

    # Überschüssige Leerzeilen bereinigen
    cleaned = re.sub(r"\n{3,}", "\n\n", "\n".join(new_lines))
    _write_file_locked(acl_path, cleaned.strip() + "\n")
    logger.info("ACL-Regeln entfernt für: %s", username)


# ---------------------------------------------------------------------------
# Kombinierte Operationen (User + ACL + Reload)
# ---------------------------------------------------------------------------


def provision_mqtt_account(
    username: str, password: str, tenant_id: str, role: str = "admin", device_id: str | None = None
) -> bool:
    """Erstellt MQTT-User + ACL-Regeln + signalisiert Reload."""
    create_mqtt_user(username, password)
    add_acl_rules(username, tenant_id, role, device_id)
    _signal_reload()
    return True


def deprovision_mqtt_account(username: str) -> bool:
    """Löscht MQTT-User + ACL-Regeln + signalisiert Reload."""
    deleted = delete_mqtt_user(username)
    remove_acl_rules(username)
    if deleted:
        _signal_reload()
    return deleted


def change_mqtt_password(username: str, new_password: str) -> bool:
    """Ändert das Passwort eines MQTT-Benutzers."""
    if not mqtt_user_exists(username):
        return False
    create_mqtt_user(username, new_password)
    _signal_reload()
    return True
