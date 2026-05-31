from __future__ import annotations

class ValidationError(Exception):
    ...


class DataRequired:
    def __init__(self, *_args: object, **_kwargs: object) -> None: ...


class Email:
    def __init__(self, *_args: object, **_kwargs: object) -> None: ...


class EqualTo:
    def __init__(self, *_args: object, **_kwargs: object) -> None: ...


class Length:
    def __init__(self, *_args: object, **_kwargs: object) -> None: ...


class Regexp:
    def __init__(self, *_args: object, **_kwargs: object) -> None: ...
