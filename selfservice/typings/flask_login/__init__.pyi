from __future__ import annotations

from collections.abc import Callable
from datetime import timedelta
from typing import Any, ParamSpec, TypeVar

from flask import Flask

_P = ParamSpec("_P")
_R = TypeVar("_R")

current_user: Any


class UserMixin:
    ...


class LoginManager:
    login_view: str | None
    login_message: str | None
    login_message_category: str | None

    def __init__(self) -> None: ...

    def init_app(
        self,
        _app: Flask,
        _add_context_processor: bool = True,
    ) -> None: ...

    def user_loader(
        self,
        _callback: Callable[[str], Any | None],
    ) -> Callable[[str], Any | None]: ...


def login_required(  # noqa: UP047
    _func: Callable[_P, _R],
) -> Callable[_P, _R]: ...


def login_user(
    _user: Any,
    _remember: bool = False,
    _duration: timedelta | None = None,
    _force: bool = False,
    _fresh: bool = True,
) -> bool: ...


def logout_user() -> None: ...
