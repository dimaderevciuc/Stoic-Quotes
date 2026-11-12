"""Runs every validation rule on the committed corpus, so a bad edit fails CI."""

from stoic_pipeline.curate import load_passages, load_quotes, validate


def test_curated_corpus_is_valid() -> None:
    quotes = load_quotes()
    assert len(quotes) >= 500
    assert validate(quotes, load_passages()) == []


def test_every_author_is_represented() -> None:
    authors = {q.author for q in load_quotes()}
    assert authors == {"Marcus Aurelius", "Seneca", "Epictetus", "James Allen"}
