from __future__ import annotations


class FlaskForm:
    def validate_on_submit(
        self,
        _extra_validators: object | None = None,
    ) -> bool: ...
