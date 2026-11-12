"""Splitters on small inline fixtures that mimic the real source formats."""

from pathlib import Path

import pytest

from stoic_pipeline.schema import Source, SourceFile
from stoic_pipeline.split import (
    roman_to_int,
    seneca_year,
    split_encheiridion,
    split_meditations,
    split_seneca_letter,
    strip_gutenberg_boilerplate,
)

DUMMY_FILE = SourceFile(path="x", url="https://example.org", sha256="0" * 64)


def source(source_id: str, author: str, work: str, year: int) -> Source:
    return Source(
        id=source_id,
        author=author,  # type: ignore[arg-type]
        work=work,
        title="t",
        translator="George Long",
        year=year,
        files=[DUMMY_FILE],
    )


MEDITATIONS_RAW = """header
*** START OF THE PROJECT GUTENBERG EBOOK THOUGHTS ***
THE THOUGHTS OF MARCUS AURELIUS ANTONIUS.

CONTENTS.

THE THOUGHTS

OF

MARCUS AURELIUS ANTONIUS.


I.


From my grandfather Verus[A] [I learned] good morals.

    [A] A footnote that must be dropped.

2. From my father, modesty
and a manly character.

II.


Begin the morning by saying to thyself (iii. 7; vi. 23).

Second paragraph of the same section.

2. Whatever this is that I am.

INDEXES.

*** END OF THE PROJECT GUTENBERG EBOOK THOUGHTS ***
footer"""


def test_roman_numerals() -> None:
    assert [roman_to_int(n) for n in ["I", "IV", "IX", "XII", "XLIX", "CXXIV"]] == [
        1,
        4,
        9,
        12,
        49,
        124,
    ]


def test_gutenberg_boilerplate_removed() -> None:
    body = strip_gutenberg_boilerplate(MEDITATIONS_RAW)
    assert "header" not in body
    assert "footer" not in body


def test_meditations_sections_and_cleanup() -> None:
    src = source("meditations-long", "Marcus Aurelius", "Meditations", 1862)
    passages = list(split_meditations(MEDITATIONS_RAW, src))

    assert [p.citation for p in passages] == [
        "Meditations 1.1",
        "Meditations 1.2",
        "Meditations 2.1",
        "Meditations 2.2",
    ]
    assert passages[0].text == "From my grandfather Verus [I learned] good morals."
    assert passages[1].text == "From my father, modesty and a manly character."
    # Cross references removed, multi paragraph sections joined.
    assert passages[2].text == (
        "Begin the morning by saying to thyself. Second paragraph of the same section."
    )


def test_meditations_rejects_skipped_section() -> None:
    raw = MEDITATIONS_RAW.replace("2. Whatever", "3. Whatever")
    src = source("meditations-long", "Marcus Aurelius", "Meditations", 1862)
    with pytest.raises(ValueError, match="section 3 follows 1"):
        list(split_meditations(raw, src))


SENECA_HTML = """<div class="mw-parser-output">
<div class="ws-header">Header to drop</div>
<p>XIII. ON GROUNDLESS FEARS</p>
<p><span class="wst-verse" id="1."><sup><b>1.</b></sup></span> I know that you have plenty
of spirit.<sup class="reference"><a href="#n1">[1]</a></sup> <span class="pagenum">​</span>More
text. <span class="wst-verse" id="2."><sup><b>2.</b></sup></span> Second section.</p>
<p>Still the second section.</p>
<ol class="references"><li>A footnote</li></ol>
</div>"""


def test_seneca_sections(tmp_path: Path) -> None:
    path = tmp_path / "letter-13.html"
    path.write_text(SENECA_HTML, encoding="utf-8")
    src = source("seneca-gummere", "Seneca", "Moral Letters to Lucilius", 1917)

    passages = list(split_seneca_letter(path, src))

    assert [p.id for p in passages] == ["sen-13-1", "sen-13-2"]
    assert passages[0].citation == "Letter 13.1"
    assert passages[0].text == "I know that you have plenty of spirit. More text."
    assert passages[1].text == "Second section. Still the second section."


def test_seneca_volume_years() -> None:
    assert [seneca_year(n) for n in (1, 65, 66, 92, 93, 124)] == [
        1917,
        1917,
        1920,
        1920,
        1925,
        1925,
    ]


ENCHEIRIDION_HTML = """<div>
<p>THE ENCHEIRIDION, OR MANUAL.</p>
<p>I.</p><p>Of things some are in our power.</p><p>A second paragraph.</p>
<p>II.</p><p>Remember that desire contains a promise.</p>
</div>"""


def test_encheiridion_chapters(tmp_path: Path) -> None:
    path = tmp_path / "the-encheiridion-or-manual.html"
    path.write_text(ENCHEIRIDION_HTML, encoding="utf-8")
    src = source("epictetus-long", "Epictetus", "Discourses and Encheiridion", 1877)

    passages = list(split_encheiridion(path, src))

    assert [(p.id, p.citation) for p in passages] == [
        ("epi-ench-1", "Enchiridion 1"),
        ("epi-ench-2", "Enchiridion 2"),
    ]
    assert passages[0].text == "Of things some are in our power. A second paragraph."


def test_meditations_drops_multi_paragraph_footnotes() -> None:
    raw = MEDITATIONS_RAW.replace(
        "2. Whatever this is that I am.",
        "[A] Note at column zero.\n\n    A second indented note paragraph.\n\n"
        "2. Whatever this is that I am.",
    )
    src = source("meditations-long", "Marcus Aurelius", "Meditations", 1862)
    texts = " ".join(p.text for p in split_meditations(raw, src))
    assert "note" not in texts.lower()


def test_seneca_sections_outside_paragraphs(tmp_path: Path) -> None:
    html = (
        '<div class="mw-parser-output"><div>LXIV. TITLE</div>'
        '<div><span class="wst-verse">1.</span> Outside a paragraph.</div>'
        '<p><span class="wst-verse">2.</span> Inside one.</p></div>'
    )
    path = tmp_path / "letter-64.html"
    path.write_text(html, encoding="utf-8")
    src = source("seneca-gummere", "Seneca", "Moral Letters to Lucilius", 1917)

    texts = [p.text for p in split_seneca_letter(path, src)]

    assert texts == ["Outside a paragraph.", "Inside one."]
