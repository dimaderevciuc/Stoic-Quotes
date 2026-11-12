"""Keyword side of crisis detection (the similarity side needs the model)."""

from stoic_pipeline.safety import keyword_hit, load_keywords, load_phrases, normalize


def test_normalize() -> None:
    assert normalize("I\u2019m NOT safe!!") == " i'm not safe "
    assert normalize("  end-it all ") == " end it all "


def test_keywords_match_whole_words() -> None:
    keywords = load_keywords()
    assert keyword_hit("I want to die", keywords) == "want to die"
    assert keyword_hit("Thinking about SUICIDE...", keywords) == "suicide"
    assert keyword_hit("I\u2019m not safe at home", keywords) is not None
    # Whole words only: "kms" must not fire inside "skms", "raped" not inside "draped".
    assert keyword_hit("the curtains were draped nicely", keywords) is None
    assert keyword_hit("we drove 300 kms today", keywords) == "kms"  # accepted false positive


def test_lists_are_clean() -> None:
    keywords = load_keywords()
    assert len(keywords) == len(set(keywords)) >= 50
    assert len(load_phrases()) >= 20
    assert all("\u2014" not in k and "\u2013" not in k for k in keywords)
