from collections.abc import Callable
from functools import wraps
from typing import Any, ParamSpec, TypeVar, cast

from flask import abort
from flask_login import current_user

P = ParamSpec("P")
R = TypeVar("R")


def admin_required(  # noqa: UP047
    view_func: Callable[P, R],
) -> Callable[P, R]:
    @wraps(view_func)
    def wrapped(*args: P.args, **kwargs: P.kwargs) -> R:
        user = cast(Any, current_user)
        if not user.is_authenticated or getattr(user, "role", None) != "admin":
            abort(403)
        return view_func(*args, **kwargs)

    return cast(Callable[P, R], wrapped)
