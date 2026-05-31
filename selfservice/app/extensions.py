from __future__ import annotations

from collections.abc import Callable
from typing import Protocol, TypeAlias, cast

from flask import Flask
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
from flask_login import LoginManager
from flask_mailman import Mail
from flask_migrate import Migrate
from flask_sqlalchemy import SQLAlchemy
from flask_wtf.csrf import CSRFProtect

UserLoaderCallback: TypeAlias = Callable[[str], object | None]  # noqa: UP040


class LoginManagerProtocol(Protocol):
    login_view: str | None
    login_message: str | None
    login_message_category: str | None

    def init_app(self, app: Flask, add_context_processor: bool = True) -> None: ...

    def user_loader(self, callback: UserLoaderCallback) -> UserLoaderCallback: ...


class CsrfProtectProtocol(Protocol):
    def init_app(self, app: Flask) -> None: ...


db = SQLAlchemy()
login_manager: LoginManagerProtocol = cast(LoginManagerProtocol, LoginManager())
csrf: CsrfProtectProtocol = cast(CsrfProtectProtocol, CSRFProtect())
limiter = Limiter(key_func=get_remote_address, default_limits=["60/minute"])
mail = Mail()
migrate = Migrate()
