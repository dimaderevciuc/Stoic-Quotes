"""Text normalization used for comparisons (never for display)."""

import re
import unicodedata

_WHITESPACE = re.compile(r"\s+")
# Curly single and double quotes mapped to straight ones.
_QUOTE_MARKS = str.maketrans({"\u2018": "'", "\u2019": "'", "\u201c": '"', "\u201d": '"'})
# Invisible characters that Wikisource inserts at page breaks.
_INVISIBLE = dict.fromkeys(map(ord, "\u200b\u200c\u200d\ufeff\u00ad"))


def clean(text: str) -> str:
    """Display cleanup: drop invisible characters and collapse whitespace."""
    text = unicodedata.normalize("NFC", text).translate(_INVISIBLE)
    return _WHITESPACE.sub(" ", text).strip()


def normalize(text: str) -> str:
    """Comparison form: like clean, plus unified quote marks and lowercase.

    Typographic and straight quotes are treated as equal so a quote typed with
    straight apostrophes still matches the curly ones in the source.
    """
    return straighten_quotes(clean(text)).lower()


def straighten_quotes(text: str) -> str:
    """Replace curly quote marks with straight ones (same length, 1:1 characters)."""
    return text.translate(_QUOTE_MARKS)
