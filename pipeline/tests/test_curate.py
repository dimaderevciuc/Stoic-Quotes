"""Cross checks between curated quotes and the source passages."""

from stoic_pipeline.curate import (
    check_against_passage,
    find_duplicate_ids,
    find_near_duplicates,
    locate_exact,
    next_quote_id,
    quote_id_base,
)
from stoic_pipeline.schema import Passage
from tests.test_schema import CONTEXT, make_quote

PASSAGE = Passage(
    id="sen-13-4",
    source_id="seneca-gummere",
    author="Seneca",
    work="Moral Letters to Lucilius",
    citation="Letter 13.4",
    translator="Richard M. Gummere",
    year=1917,
    text=CONTEXT,
)


def test_matching_quote_has_no_problems() -> None:
    assert check_against_passage(make_quote(), {PASSAGE.id: PASSAGE}) == []


def test_unknown_passage_reported() -> None:
    problems = check_against_passage(make_quote(passage_id="sen-99-1"), {PASSAGE.id: PASSAGE})
    assert problems == ["sen-13-4-a: unknown passage_id sen-99-1"]


def test_wrong_citation_reported() -> None:
    problems = check_against_passage(make_quote(citation="Letter 13.5"), {PASSAGE.id: PASSAGE})
    assert any("citation" in p for p in problems)


def test_context_must_be_the_real_passage() -> None:
    # A quote that carries its own invented context still fails against the real passage.
    fake_context = "Some invented words, and we suffer more often in imagination than in reality."
    quote = make_quote(context=fake_context)
    problems = check_against_passage(quote, {PASSAGE.id: PASSAGE})
    assert any("context differs" in p for p in problems)


def test_duplicate_ids_reported() -> None:
    assert find_duplicate_ids([make_quote(), make_quote()]) == ["duplicate id: sen-13-4-a"]


def test_near_duplicates_reported() -> None:
    first = make_quote()
    second = make_quote(id="sen-13-4-b", text="we suffer more often in imagination than in reality")
    assert find_near_duplicates([first, second])


def test_different_quotes_are_not_duplicates() -> None:
    first = make_quote()
    second = make_quote(
        id="sen-13-4-b",
        text="There are more things, Lucilius, likely to frighten us than there are to crush us",
    )
    assert find_near_duplicates([first, second]) == []


def test_locate_exact_restores_curly_quotes() -> None:
    passage = "He said, “I am not a hindrance to myself.” Then he left."
    found = locate_exact('"I am not a hindrance to myself."', passage)
    assert found == "“I am not a hindrance to myself.”"


def test_locate_exact_requires_same_words() -> None:
    assert locate_exact("I am not a hindrance to me.", "I am not a hindrance to myself.") is None


def test_discourse_quote_ids_use_chapter() -> None:
    assert quote_id_base("epi-1-1-p3") == "epi-1-1"
    assert quote_id_base("ma-4-3") == "ma-4-3"
    assert next_quote_id("ma-4-3", {"ma-4-3-a"}) == "ma-4-3-b"
