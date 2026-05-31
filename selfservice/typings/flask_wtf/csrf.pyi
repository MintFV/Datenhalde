from __future__ import annotations

from flask import Flask


class CSRFProtect:
    def __init__(self) -> None: ...

    def init_app(self, _app: Flask) -> None: ...
