"""The situation library is valid and the combined ranking behaves (no model needed)."""

import numpy as np

from stoic_pipeline.schema import Situation
from stoic_pipeline.situations import combined_ranking, load_situations, validate_situations


def test_library_is_valid() -> None:
    situations = load_situations()
    assert len(situations) == 151
    assert validate_situations(situations) == []
    assert all(s.reviewed for s in situations)


def test_abuse_situations_point_to_help() -> None:
    by_id = {s.id: s for s in load_situations()}
    for sid in ("controlling-partner", "hurt-at-home"):
        assert by_id[sid].is_sensitive
        assert "112" in by_id[sid].exercise[0]


def _situation(sid: str, quotes: list[str]) -> Situation:
    return Situation(
        id=sid,
        title="A test situation",
        category="work",
        example_phrases=[f"phrase {i}" for i in range(6)],
        quote_ids=quotes,
        applications={q: "Applies." for q in quotes},
        exercise=["One.", "Two."],
        is_sensitive=False,
    )


def test_combined_ranking() -> None:
    docs = np.eye(4, dtype=np.float32)  # quote i points along axis i
    quote_ids = ["q0", "q1", "q2", "q3"]
    sit_vecs = np.array([[1, 0, 0, 0]], dtype=np.float32)
    situations = [_situation("s", ["q3", "q2", "q1"])]
    query = np.array([1, 0, 0, 0], dtype=np.float32)
    shown = combined_ranking(query, docs, quote_ids, sit_vecs, situations, 0.9)
    assert shown.situation == "s"
    assert shown.ranked == ["q3", "q2", "q1", "q0"]
    hidden = combined_ranking(query, docs, quote_ids, sit_vecs, situations, 1.1)
    assert hidden.situation is None
    assert hidden.ranked[0] == "q0"
