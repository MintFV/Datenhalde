from __future__ import annotations

from typing import Any

class Field:
    data: Any


class StringField(Field):
    def __init__(self, *_args: object, **_kwargs: object) -> None: ...


class PasswordField(Field):
    def __init__(self, *_args: object, **_kwargs: object) -> None: ...


class SubmitField(Field):
    def __init__(self, *_args: object, **_kwargs: object) -> None: ...


class SelectField(Field):
    def __init__(self, *_args: object, **_kwargs: object) -> None: ...
