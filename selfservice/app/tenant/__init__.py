from flask import Blueprint

bp = Blueprint("tenant", __name__)

from . import routes  # noqa: E402, F401
