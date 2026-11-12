"""Character tables that let the Dart tokenizer copy the HF BertNormalizer exactly.

Dart has no Unicode normalization (NFD) or general category lookup, so instead of
reimplementing them we ask the real tokenizer what it does to every code point and
export the answers. The tables are only valid because the normalizer works one
code point at a time (checked in tests): normalize(s) == concat(normalize(c)).
"""

from __future__ import annotations

from collections.abc import Iterable
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from tokenizers import Tokenizer

MAX_CODE_POINT = 0x10FFFF


def require(condition: bool, message: str) -> None:
    """Like assert, but not removed by python -O: the export must never be silently wrong."""
    if not condition:
        raise ValueError(message)


def code_points() -> Iterable[int]:
    # Surrogates are not valid scalar values and cannot appear in a Dart rune either.
    return (cp for cp in range(MAX_CODE_POINT + 1) if not 0xD800 <= cp <= 0xDFFF)


def to_ranges(sorted_cps: list[int]) -> list[list[int]]:
    """[1, 2, 3, 7] -> [[1, 3], [7, 7]] (inclusive), to keep the JSON small."""
    out: list[list[int]] = []
    for cp in sorted_cps:
        if out and cp == out[-1][1] + 1:
            out[-1][1] = cp
        else:
            out.append([cp, cp])
    return out


def char_tables(tokenizer: Tokenizer) -> dict[str, object]:
    normalizer = tokenizer.normalizer
    pre = tokenizer.pre_tokenizer
    require(normalizer is not None and pre is not None, "unexpected tokenizer layout")
    deleted: list[int] = []
    spaced: list[int] = []  # CJK ideographs get a space on each side
    mapped: dict[str, str] = {}
    punctuation: list[int] = []
    whitespace: list[int] = []
    for cp in code_points():
        char = chr(cp)
        out = normalizer.normalize_str(char)
        if out == "":
            deleted.append(cp)
        elif out == f" {char} ":
            spaced.append(cp)
        elif out != char:
            mapped[str(cp)] = out
        # The pre-tokenizer splits on whitespace and isolates punctuation; probe it
        # between two letters to see which case applies.
        pieces = [p for p, _ in pre.pre_tokenize_str(f"a{char}a")]
        if pieces == ["a", "a"]:
            whitespace.append(cp)
        elif pieces == ["a", char, "a"]:
            punctuation.append(cp)
    return {
        "deleted": to_ranges(deleted),
        "spaced": to_ranges(spaced),
        "mapped": mapped,
        "punctuation": to_ranges(punctuation),
        "whitespace": to_ranges(whitespace),
    }
