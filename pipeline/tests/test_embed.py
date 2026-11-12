"""Offline tests for the embedding export (no model download needed)."""

from pathlib import Path

import numpy as np

from stoic_pipeline.charmap import to_ranges
from stoic_pipeline.embed import (
    EvalCase,
    dequantize,
    load_eval,
    load_quotes,
    quantize_rows,
    read_matrix,
    score,
    write_matrix,
)


def test_to_ranges() -> None:
    assert to_ranges([1, 2, 3, 7, 9, 10]) == [[1, 3], [7, 7], [9, 10]]
    assert to_ranges([]) == []


def test_quantize_round_trip_is_close() -> None:
    rng = np.random.default_rng(0)
    matrix = rng.normal(size=(50, 16)).astype(np.float32)
    matrix[3] = 0  # an all zero row must not divide by zero
    q, scales = quantize_rows(matrix)
    assert q.dtype == np.int8
    # Rounding error is at most half a step per value.
    assert np.all(np.abs(dequantize(q, scales) - matrix) <= scales[:, None] / 2 + 1e-7)


def test_matrix_file_round_trip(tmp_path: Path) -> None:
    q = np.arange(-6, 6, dtype=np.int8).reshape(3, 4)
    scales = np.array([0.5, 1.0, 2.0], dtype=np.float32)
    write_matrix(tmp_path / "m.bin", q, scales)
    q2, s2 = read_matrix(tmp_path / "m.bin")
    assert np.array_equal(q, q2)
    assert np.array_equal(scales, s2)


def test_score() -> None:
    cases = [
        EvalCase(id="a", text="x", relevant=["q1", "q2"]),
        EvalCase(id="b", text="y", relevant=["q9"]),
    ]
    s = score([["q2", "q3", "q4", "q5", "q6", "q1"], ["q1", "q2", "q3", "q4", "q5", "q9"]], cases)
    assert s.recall == 0.25  # (1 of 2 + 0 of 1) / 2
    assert s.hit == 0.5
    assert abs(s.mrr - (1.0 + 1 / 6) / 2) < 1e-9


def test_eval_set_points_at_real_quotes() -> None:
    ids = {q.id for q in load_quotes()}
    cases = load_eval()
    assert len(cases) == 50
    assert len({c.id for c in cases}) == 50
    for case in cases:
        assert 3 <= len(case.relevant) <= 12
        assert set(case.relevant) <= ids, case.id
