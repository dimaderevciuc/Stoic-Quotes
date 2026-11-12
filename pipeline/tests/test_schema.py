"""Quote validation rules: these protect against invented or misattributed quotes."""

from typing import Any

import pytest
from pydantic import ValidationError

from stoic_pipeline.schema import Quote

CONTEXT = (
    "There are more things, Lucilius, likely to frighten us than there are to crush us; "
    "we suffer more often in imagination than in reality."
)


def make_quote(**overrides: Any) -> Quote:  # noqa: ANN401
    fields: dict[str, Any] = {
        "id": "sen-13-4-a",
        "text": "we suffer more often in imagination than in reality.",
        "author": "Seneca",
        "work": "Moral Letters to Lucilius",
        "citation": "Letter 13.4",
        "translator": "Richard M. Gummere",
        "year": 1917,
        "passage_id": "sen-13-4",
        "context": CONTEXT,
        "explanation": "Most of what we dread never happens, or is milder than we imagined.",
        "themes": ["fear", "anxiety"],
        "needs": ["calm", "perspective"],
    }
    return Quote(**(fields | overrides))


def test_valid_quote_passes() -> None:
    assert make_quote().id == "sen-13-4-a"


def test_whitespace_differences_are_allowed() -> None:
    make_quote(text="we suffer  more often in\nimagination than in reality.")


@pytest.mark.parametrize(
    "text",
    [
        "We suffer more often in imagination than in reality.",  # case changed
        "we suffer more often in our imagination than in reality.",  # word added
        "we suffer more in imagination than we do in reality, my friend.",  # paraphrase
    ],
)
def test_text_must_be_exact_substring(text: str) -> None:
    with pytest.raises(ValidationError, match="exact substring"):
        make_quote(text=text)


@pytest.mark.parametrize("bad_id", ["sen-13-4", "SEN-13-4-a", "plato-1-a", "sen_13_4_a"])
def test_id_format(bad_id: str) -> None:
    with pytest.raises(ValidationError, match="id"):
        make_quote(id=bad_id)


def test_length_limits() -> None:
    with pytest.raises(ValidationError, match="length"):
        make_quote(text="than in reality.")


def test_unknown_theme_rejected() -> None:
    with pytest.raises(ValidationError, match="unknown themes"):
        make_quote(themes=["fear", "dragons"])


def test_author_must_be_a_stoic() -> None:
    with pytest.raises(ValidationError):
        make_quote(author="Lao Tzu")


def test_explanation_without_dashes() -> None:
    with pytest.raises(ValidationError, match="dashes"):
        make_quote(explanation="Fear lies — mostly.")


def test_unknown_fields_rejected() -> None:
    with pytest.raises(ValidationError):
        make_quote(popularity=5)
