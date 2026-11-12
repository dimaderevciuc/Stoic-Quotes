"""Pydantic models shared by every pipeline step.

All models are frozen and forbid unknown fields, so a typo in a JSONL file
fails loudly instead of silently dropping data.
"""

from __future__ import annotations

import re
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

from stoic_pipeline.text import clean

# James Allen is not a Stoic, but As a Man Thinketh (1903) was added at Dima's request.
Author = Literal["Marcus Aurelius", "Seneca", "Epictetus", "James Allen"]

# Controlled vocabularies keep tags consistent, so matching and filtering stay reliable.
THEMES: frozenset[str] = frozenset(
    {
        "acceptance",
        "adversity",
        "anger",
        "anxiety",
        "change",
        "character",
        "community",
        "control",
        "death",
        "desire",
        "duty",
        "failure",
        "fear",
        "friendship",
        "gratitude",
        "grief",
        "humility",
        "judgment",
        "kindness",
        "learning",
        "loneliness",
        "nature",
        "opinion-of-others",
        "pain",
        "patience",
        "poverty",
        "present-moment",
        "self-discipline",
        "simplicity",
        "time",
        "virtue",
        "wealth",
        "work",
    }
)

NEEDS: frozenset[str] = frozenset(
    {
        "acceptance",
        "calm",
        "clarity",
        "comfort",
        "courage",
        "discipline",
        "forgiveness",
        "humility",
        "motivation",
        "perspective",
        "resilience",
        "self-compassion",
    }
)

QUOTE_ID_PATTERN = re.compile(r"^(ma|sen|epi|ja)-[a-z0-9]+(-[a-z0-9]+)*-[a-z]$")
MIN_QUOTE_CHARS = 40
MAX_QUOTE_CHARS = 400


class StrictModel(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid", str_strip_whitespace=True)


class SourceFile(StrictModel):
    """One downloaded file, pinned by revision and checksum for reproducibility."""

    path: str  # relative to data/raw/
    url: str
    revision: int | None = None  # Wikisource revision id, None for Gutenberg
    sha256: str = Field(pattern=r"^[0-9a-f]{64}$")


class Source(StrictModel):
    id: str
    author: Author
    work: str
    title: str  # title of the edition as published
    translator: str  # empty for works written in English
    year: int
    year_note: str = ""
    files: list[SourceFile]


class Passage(StrictModel):
    """A citable unit of source text (a section, a paragraph, or a chapter)."""

    id: str
    source_id: str
    author: Author
    work: str
    citation: str
    translator: str
    year: int
    text: str


class Quote(StrictModel):
    id: str
    text: str
    author: Author
    work: str
    citation: str  # e.g. "Meditations 4.3"
    translator: str
    year: int
    passage_id: str
    context: str  # the full source passage, shown in the app
    explanation: str  # 1 to 3 plain sentences, what it means today
    themes: list[str] = Field(min_length=1)
    needs: list[str] = Field(min_length=1)
    reviewed: bool = False

    @field_validator("id")
    @classmethod
    def _id_format(cls, value: str) -> str:
        if not QUOTE_ID_PATTERN.match(value):
            examples = "ma-4-3-a, sen-13-4-a, epi-ench-1-a, ja-2-a"
            raise ValueError(f"id {value!r} must look like {examples}")
        return value

    @field_validator("text")
    @classmethod
    def _length(cls, value: str) -> str:
        length = len(clean(value))
        if not MIN_QUOTE_CHARS <= length <= MAX_QUOTE_CHARS:
            raise ValueError(f"quote length {length} outside {MIN_QUOTE_CHARS}..{MAX_QUOTE_CHARS}")
        return value

    @field_validator("themes")
    @classmethod
    def _known_themes(cls, value: list[str]) -> list[str]:
        unknown = set(value) - THEMES
        if unknown:
            raise ValueError(f"unknown themes: {sorted(unknown)}")
        return value

    @field_validator("needs")
    @classmethod
    def _known_needs(cls, value: list[str]) -> list[str]:
        unknown = set(value) - NEEDS
        if unknown:
            raise ValueError(f"unknown needs: {sorted(unknown)}")
        return value

    @field_validator("explanation")
    @classmethod
    def _no_dashes(cls, value: str) -> str:
        # House style: our own writing uses no em or en dashes (source quotes are left exact).
        if "\u2014" in value or "\u2013" in value:
            raise ValueError("explanation must not contain em or en dashes")
        return value

    @model_validator(mode="after")
    def _text_inside_context(self) -> Quote:
        # Core anti-fabrication rule: the quote must be copied, not paraphrased.
        # Only whitespace is normalized; case, punctuation and quote marks must match.
        if clean(self.text) not in clean(self.context):
            raise ValueError(f"{self.id}: quote text is not an exact substring of its context")
        return self
