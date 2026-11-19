import re
from collections.abc import Iterable

TENANT_ID_RE = re.compile(r"^[a-z]{2}-[a-z]{2}-[a-z0-9-]+$")

BUNDESLAENDER = [
    ("bw", "Baden-Württemberg"),
    ("by", "Bayern"),
    ("be", "Berlin"),
    ("bb", "Brandenburg"),
    ("hb", "Bremen"),
    ("hh", "Hamburg"),
    ("he", "Hessen"),
    ("mv", "Mecklenburg-Vorpommern"),
    ("ni", "Niedersachsen"),
    ("nrw", "Nordrhein-Westfalen"),
    ("rp", "Rheinland-Pfalz"),
    ("sl", "Saarland"),
    ("sn", "Sachsen"),
    ("st", "Sachsen-Anhalt"),
    ("sh", "Schleswig-Holstein"),
    ("th", "Thüringen"),
]

SCHOOL_TYPES = [
    ("gs", "Grundschule"),
    ("gym", "Gymnasium"),
    ("rs", "Realschule"),
    ("ag", "Arbeitsgruppe"),
    ("privat", "Privatperson"),
]


def is_valid_tenant_id(value: str) -> bool:
    return bool(TENANT_ID_RE.fullmatch(value))


def generate_tenant_id(
    name: str,
    bundesland: str,
    school_type: str,
    existing: Iterable[str],
) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")[:40]
    if not slug:
        slug = "tenant"
    base = f"de-{bundesland}-{school_type}-{slug}"
    taken = set(existing)
    candidate = base
    suffix = 2
    while candidate in taken:
        candidate = f"{base}-{suffix}"
        suffix += 1
    return candidate
