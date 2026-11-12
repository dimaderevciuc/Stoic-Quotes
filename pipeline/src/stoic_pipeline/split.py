"""Split the raw source files into citable passages.

Run: uv run stoic-split

Output: data/passages/<source_id>.jsonl, one Passage per line.
- Meditations: one passage per numbered section (Meditations 4.3).
- Discourses: one passage per paragraph, cited by book and chapter (Discourses 1.1),
  because Long's translation has no section numbers.
- Encheiridion: one passage per chapter (Enchiridion 5).
- Seneca: one passage per numbered section (Letter 13.4).
"""

from __future__ import annotations

import re
from collections.abc import Iterator
from pathlib import Path

import typer
from bs4 import BeautifulSoup

from stoic_pipeline.download import load_sources
from stoic_pipeline.jsonl import write_jsonl
from stoic_pipeline.paths import PASSAGES, RAW
from stoic_pipeline.schema import Passage, Source
from stoic_pipeline.text import clean

ROMAN = {"I": 1, "V": 5, "X": 10, "L": 50, "C": 100}


def roman_to_int(numeral: str) -> int:
    total = 0
    values = [ROMAN[ch] for ch in numeral.upper()]
    for current, following in zip(values, [*values[1:], 0], strict=True):
        total += -current if current < following else current
    return total


# --- Meditations (Project Gutenberg plain text) ---------------------------------------------

_GUTENBERG_START = re.compile(r"\*\*\* START OF THE PROJECT GUTENBERG EBOOK.*?\*\*\*")
_GUTENBERG_END = re.compile(r"\*\*\* END OF THE PROJECT GUTENBERG EBOOK")
_MA_TEXT_START = "MARCUS AURELIUS ANTONIUS.\n"  # heading right before Book I
_MA_TEXT_END = "\nINDEXES.\n"
_MA_BOOK = re.compile(r"^([IVX]+)\.$")
_MA_SECTION = re.compile(r"^(\d+)\.\s+")
_MA_FOOTNOTE_BLOCK = re.compile(r"^\s*\[[A-Z]\]")
_MA_FOOTNOTE_MARK = re.compile(r"\[[A-Z]\]")
# Long marks doubtful readings with "+", e.g. "is sufficient.+" or "except + indeed".
_MA_DOUBT_MARK = re.compile(r"\+")
_MA_ILLUSTRATION = re.compile(r"\[Illustration:[^\]]*\]")
# Long's own cross references, e.g. "(iii. 7; vi. 23; x. 20)": editorial, not Marcus.
_MA_CROSS_REF = re.compile(
    r"\s*\((?=[ivxl]+\.\s*(?:c\.\s*)?\d)(?:[ivxl]+\.|c\.|\d+|note|[\s.,;])+\)"
)


def strip_gutenberg_boilerplate(raw: str) -> str:
    start = _GUTENBERG_START.search(raw)
    end = _GUTENBERG_END.search(raw)
    if not start or not end:
        raise ValueError("Gutenberg start or end marker not found")
    return raw[start.end() : end.start()]


def _meditations_body(raw: str) -> str:
    text = strip_gutenberg_boilerplate(raw).replace("\r\n", "\n")
    # The heading also appears on the title page, so take the last one before the books.
    start = text.rindex(_MA_TEXT_START, 0, text.index("\nI.\n")) + len(_MA_TEXT_START)
    end = text.index(_MA_TEXT_END, start)
    return text[start:end]


def _clean_meditations_block(block: str) -> str:
    text = _MA_FOOTNOTE_MARK.sub("", block)
    text = _MA_DOUBT_MARK.sub("", text)
    text = _MA_ILLUSTRATION.sub("", text)
    text = _MA_CROSS_REF.sub("", text)
    return clean(text)


def split_meditations(raw: str, source: Source) -> Iterator[Passage]:
    book = 0
    section = 0
    parts: list[str] = []

    def flush() -> Iterator[Passage]:
        if book and section and parts:
            yield Passage(
                id=f"ma-{book}-{section}",
                source_id=source.id,
                author=source.author,
                work=source.work,
                citation=f"Meditations {book}.{section}",
                translator=source.translator,
                year=source.year,
                text=" ".join(parts),
            )

    in_footnote = False
    for block in re.split(r"\n\s*\n", _meditations_body(raw)):
        if not block.strip():
            continue
        # Footnotes start with "[A]"; their extra paragraphs are indented like the first.
        if _MA_FOOTNOTE_BLOCK.match(block) or (in_footnote and block[:1].isspace()):
            in_footnote = True
            continue
        in_footnote = False
        book_match = _MA_BOOK.match(block.strip())
        if book_match:
            yield from flush()
            book, section, parts = roman_to_int(book_match.group(1)), 1, []
            continue
        section_match = _MA_SECTION.match(block)
        if section_match:
            number = int(section_match.group(1))
            if number != section + 1:
                raise ValueError(f"Meditations {book}: section {number} follows {section}")
            yield from flush()
            section, parts = number, []
            block = block[section_match.end() :]
        cleaned = _clean_meditations_block(block)
        if cleaned:  # illustration captions leave empty blocks behind
            parts.append(cleaned)
    yield from flush()


# --- Wikisource HTML helpers ----------------------------------------------------------------

# Elements that are not part of the translated text.
_WIKISOURCE_NOISE = ", ".join(
    [
        "style",
        "link",
        "sup.reference",
        ".references",
        ".reflist",
        ".ws-header",
        ".ws-noexport",
        ".mw-editsection",
        ".pagenum",
        "[style*='display:none']",
        ".wst-fqm",  # hanging quote mark duplicated for layout
    ]
)


def _soup(path: Path) -> BeautifulSoup:
    soup = BeautifulSoup(path.read_text(encoding="utf-8"), "html.parser")
    for element in soup.select(_WIKISOURCE_NOISE):
        element.decompose()
    return soup


def _paragraph_texts(soup: BeautifulSoup) -> list[str]:
    texts = [clean(p.get_text("")) for p in soup.find_all("p")]
    return [t for t in texts if t]


_BLOCK_TAGS = ["p", "div", "br", "li", "dd", "tr", "h1", "h2", "h3", "h4"]


def _block_text(soup: BeautifulSoup) -> str:
    """All text of the page, with a space between block elements.

    Some letters have sections outside <p> tags, so reading only paragraphs loses text.
    """
    for tag in soup.find_all(_BLOCK_TAGS):
        tag.insert_after(" ")
    return clean(soup.get_text(""))


# --- Epictetus (Wikisource, Long 1877) ------------------------------------------------------

_HEADING = re.compile(r"^(BOOK|CHAPTER)\s+[IVXL]+\.?$")
_ENCH_HEADING = re.compile(r"^([IVXL]+)\.$")
_DISCOURSE_FILE = re.compile(r"book-(\d+)-chapter-(\d+)\.html$")


def split_discourse_chapter(path: Path, source: Source) -> Iterator[Passage]:
    match = _DISCOURSE_FILE.search(path.name)
    if not match:
        raise ValueError(f"unexpected file name {path.name}")
    book, chapter = int(match.group(1)), int(match.group(2))
    paragraphs = [p for p in _paragraph_texts(_soup(path)) if not _HEADING.match(p)]
    # The first paragraph after the headings is the chapter title, not Epictetus' words.
    for index, text in enumerate(paragraphs[1:], start=1):
        yield Passage(
            id=f"epi-{book}-{chapter}-p{index}",
            source_id=source.id,
            author=source.author,
            work="Discourses",
            citation=f"Discourses {book}.{chapter}",
            translator=source.translator,
            year=source.year,
            text=text,
        )


def split_encheiridion(path: Path, source: Source) -> Iterator[Passage]:
    chapter = 0
    chapters: dict[int, list[str]] = {}
    for text in _paragraph_texts(_soup(path)):
        heading = _ENCH_HEADING.match(text)
        if heading:
            number = roman_to_int(heading.group(1))
            if number != chapter + 1:
                raise ValueError(f"Encheiridion chapter {number} follows {chapter}")
            chapter = number
            chapters[chapter] = []
        elif chapter:
            chapters[chapter].append(text)
    for number, parts in chapters.items():
        yield Passage(
            id=f"epi-ench-{number}",
            source_id=source.id,
            author=source.author,
            work="Enchiridion",
            citation=f"Enchiridion {number}",
            translator=source.translator,
            year=source.year,
            text=" ".join(parts),
        )


# --- Seneca (Wikisource, Gummere Loeb) ------------------------------------------------------

_SECTION_MARKER = "\u0000"
_LETTER_FILE = re.compile(r"letter-(\d+)\.html$")


def seneca_year(letter: int) -> int:
    """Publication year of the Loeb volume that contains a letter."""
    if letter <= 65:
        return 1917
    if letter <= 92:
        return 1920
    return 1925


def split_seneca_letter(path: Path, source: Source) -> Iterator[Passage]:
    match = _LETTER_FILE.search(path.name)
    if not match:
        raise ValueError(f"unexpected file name {path.name}")
    letter = int(match.group(1))
    soup = _soup(path)
    # Replace each section number badge with a marker, then split the text on the markers.
    for badge in soup.select("span.wst-verse"):
        number = badge.get_text("").strip().rstrip(".")
        badge.replace_with(f"{_SECTION_MARKER}{number}{_SECTION_MARKER}")
    pieces = _block_text(soup).split(_SECTION_MARKER)
    # pieces = [preamble, "1", text1, "2", text2, ...]; the preamble is title and greeting.
    expected = 1
    for number_text, text in zip(pieces[1::2], pieces[2::2], strict=True):
        number = int(number_text)
        if number != expected:
            raise ValueError(f"Letter {letter}: section {number}, expected {expected}")
        expected += 1
        yield Passage(
            id=f"sen-{letter}-{number}",
            source_id=source.id,
            author=source.author,
            work=source.work,
            citation=f"Letter {letter}.{number}",
            translator=source.translator,
            year=seneca_year(letter),
            text=clean(text),
        )
    if expected == 1:
        raise ValueError(f"Letter {letter}: no numbered sections found")


# --- Driver ---------------------------------------------------------------------------------


def split_source(source: Source) -> list[Passage]:
    passages: list[Passage] = []
    for file in source.files:
        path = RAW / file.path
        if source.id == "meditations-long":
            passages.extend(split_meditations(path.read_text(encoding="utf-8"), source))
        elif source.id == "epictetus-long" and "encheiridion" in path.name:
            passages.extend(split_encheiridion(path, source))
        elif source.id == "epictetus-long":
            passages.extend(split_discourse_chapter(path, source))
        elif source.id == "seneca-gummere":
            passages.extend(split_seneca_letter(path, source))
        else:
            raise ValueError(f"no splitter for source {source.id}")
    ids = [p.id for p in passages]
    if len(ids) != len(set(ids)):
        raise ValueError(f"{source.id}: duplicate passage ids")
    return passages


app = typer.Typer(help="Split raw texts into citable passages.")


@app.command()
def main() -> None:
    for source in load_sources():
        passages = split_source(source)
        write_jsonl(PASSAGES / f"{source.id}.jsonl", passages)
        typer.echo(f"{source.id}: {len(passages)} passages")
