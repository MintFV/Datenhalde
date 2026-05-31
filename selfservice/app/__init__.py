from flask import Flask

from .config import Config
from .extensions import csrf, db, limiter, login_manager, mail, migrate


def create_app() -> Flask:
    app = Flask(__name__, static_url_path="/selfservice/static")
    app.config.from_object(Config)

    # Initialisiere Extensions
    db.init_app(app)
    migrate.init_app(app, db)
    login_manager.init_app(app)
    csrf.init_app(app)
    limiter.init_app(app)
    mail.init_app(app)

    login_manager.login_view = "auth.login"
    login_manager.login_message = "Bitte melde dich an, um auf diese Seite zuzugreifen."
    login_manager.login_message_category = "warning"

    from .models import User

    @login_manager.user_loader
    def load_user(user_id: str) -> User | None:
        try:
            parsed_user_id = int(user_id)
        except (TypeError, ValueError):
            return None

        return db.session.get(User, parsed_user_id)

    # Blueprints registrieren
    from .auth import bp as auth_bp

    app.register_blueprint(auth_bp, url_prefix="/selfservice")

    from .dashboard import bp as dashboard_bp

    app.register_blueprint(dashboard_bp, url_prefix="/selfservice")

    from .mqtt import bp as mqtt_bp

    app.register_blueprint(mqtt_bp, url_prefix="/selfservice/mqtt")

    # Health-Endpunkt (für Docker-Healthcheck + nginx)
    @app.route("/selfservice/health")
    def health():
        return {"status": "ok"}, 200

    return app
