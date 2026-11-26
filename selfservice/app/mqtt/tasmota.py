from __future__ import annotations

FULL_TOPIC = "umweltbox/%topic%/%prefix%/"

INVALID_PASSWORD_MESSAGE = (
    "Das Passwort enthält Zeichen, die die Tasmota-Backlog-Syntax nicht erlaubt "
    "(Semikolon, Anführungszeichen, Backslash oder Steuerzeichen)."
)


def is_tasmota_password_safe(password: str) -> bool:
    return not any(char in ';"\\' or ord(char) < 32 or ord(char) == 127 for char in password)


def build_tasmota_backlog(
    domain: str,
    topic: str,
    username: str,
    password: str,
    client: str,
) -> str:
    if not is_tasmota_password_safe(password):
        raise ValueError(INVALID_PASSWORD_MESSAGE)
    return (
        f"Backlog0 MqttHost {domain}; MqttPort 8883; MqttUser {username}; "
        f"MqttPassword {password}; MqttClient {client}; Topic {topic}; "
        f"FullTopic {FULL_TOPIC}; SetOption3 1; TelePeriod 300"
    )
