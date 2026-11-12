"""Download the public domain source texts and record their provenance.

Run: uv run stoic-download

Writes raw files to data/raw/<source_id>/ and data/sources.json with the URL,
Wikisource revision id and SHA-256 of every file.
"""

from __future__ import annotations

import hashlib
import json
import time
from dataclasses import dataclass
from pathlib import Path

import httpx
import typer

from stoic_pipeline.paths import RAW, SOURCES_JSON
from stoic_pipeline.schema import Author, Source, SourceFile

WIKISOURCE_API = "https://en.wikisource.org/w/api.php"
# Generic client name: no personal details are sent to external services.
USER_AGENT = "stoic-pipeline/0.1 (offline corpus build; httpx)"
REQUEST_DELAY_SECONDS = 1.5  # be polite to the Wikimedia API
MAX_ATTEMPTS = 6
TIMEOUT = httpx.Timeout(60.0)

EPICTETUS_BASE = "The Discourses of Epictetus; with the Encheiridion and Fragments"
SENECA_BASE = "Moral letters to Lucilius"


@dataclass(frozen=True)
class GutenbergSpec:
    source_id: str
    ebook_id: int
    author: Author
    work: str
    title: str
    translator: str
    year: int
    year_note: str


@dataclass(frozen=True)
class WikisourceSpec:
    source_id: str
    pages: list[str]
    author: Author
    work: str
    title: str
    translator: str
    year: int
    year_note: str


MEDITATIONS = GutenbergSpec(
    source_id="meditations-long",
    ebook_id=15877,
    author="Marcus Aurelius",
    work="Meditations",
    title="Thoughts of the Emperor Marcus Aurelius Antoninus",
    translator="George Long",
    year=1862,
    year_note="The Gutenberg file states no edition year; 1862 is the first edition of Long's "
    "translation. Long died in 1879.",
)


def _epictetus_pages() -> list[str]:
    chapters_per_book = {1: 30, 2: 26, 3: 26, 4: 13}
    pages = [
        f"{EPICTETUS_BASE}/Book {book}/Chapter {chapter}"
        for book, count in chapters_per_book.items()
        for chapter in range(1, count + 1)
    ]
    # Fragments are left out on purpose: many are of doubtful authenticity.
    return [*pages, f"{EPICTETUS_BASE}/The Encheiridion or Manual"]


EPICTETUS = WikisourceSpec(
    source_id="epictetus-long",
    pages=_epictetus_pages(),
    author="Epictetus",
    work="Discourses and Encheiridion",
    title=EPICTETUS_BASE,
    translator="George Long",
    year=1877,
    year_note="Year from the Wikisource header (PD-US, translator died 1879).",
)

SENECA = WikisourceSpec(
    source_id="seneca-gummere",
    pages=[f"{SENECA_BASE}/Letter {n}" for n in range(1, 125)],
    author="Seneca",
    work="Moral Letters to Lucilius",
    title="Ad Lucilium epistulae morales (Loeb Classical Library)",
    translator="Richard M. Gummere",
    year=1917,
    year_note="Volume 1 (letters 1 to 65) 1917, volume 2 (66 to 92) 1920, volume 3 (93 to 124) "
    "1925. Per letter years are set in split.py. Translator died 1930.",
)


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _slug(page_title: str) -> str:
    """File name for a Wikisource page, e.g. 'Book 1/Chapter 3' -> 'book-1-chapter-3'."""
    tail = page_title.split("/", 1)[1]
    return tail.lower().replace("/", "-").replace(" ", "-")


def _write(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def download_gutenberg(client: httpx.Client, spec: GutenbergSpec) -> Source:
    url = f"https://www.gutenberg.org/cache/epub/{spec.ebook_id}/pg{spec.ebook_id}.txt"
    response = client.get(url)
    response.raise_for_status()
    relative = f"{spec.source_id}/pg{spec.ebook_id}.txt"
    _write(RAW / relative, response.content)
    return Source(
        id=spec.source_id,
        author=spec.author,
        work=spec.work,
        title=spec.title,
        translator=spec.translator,
        year=spec.year,
        year_note=spec.year_note,
        files=[SourceFile(path=relative, url=url, sha256=_sha256(response.content))],
    )


def _fetch_wikisource_page(client: httpx.Client, title: str) -> tuple[str, int]:
    """Return (rendered HTML, revision id) of a page, with page transclusions expanded."""
    params = {
        "action": "parse",
        "page": title,
        "prop": "text|revid",
        "format": "json",
        "formatversion": "2",
        "redirects": "1",
    }
    for attempt in range(MAX_ATTEMPTS):
        response = client.get(WIKISOURCE_API, params=params)
        if response.status_code == 200:
            payload = response.json()
            if "error" in payload:
                raise RuntimeError(f"{title}: {payload['error'].get('info')}")
            return payload["parse"]["text"], int(payload["parse"]["revid"])
        if response.status_code not in (429, 500, 502, 503, 504):
            response.raise_for_status()
        time.sleep(_retry_delay(response, attempt))
    raise RuntimeError(f"{title}: still rate limited after {MAX_ATTEMPTS} attempts")


def _retry_delay(response: httpx.Response, attempt: int) -> float:
    """Honor the server's Retry-After header, else back off exponentially."""
    retry_after = response.headers.get("Retry-After", "")
    if retry_after.isdigit():
        return float(retry_after)
    return 5.0 * 2**attempt


def download_wikisource(client: httpx.Client, spec: WikisourceSpec) -> Source:
    files: list[SourceFile] = []
    with typer.progressbar(spec.pages, label=spec.source_id) as pages:
        for title in pages:
            html, revision = _fetch_wikisource_page(client, title)
            data = html.encode("utf-8")
            relative = f"{spec.source_id}/{_slug(title)}.html"
            _write(RAW / relative, data)
            url = f"https://en.wikisource.org/w/index.php?oldid={revision}"
            files.append(
                SourceFile(path=relative, url=url, revision=revision, sha256=_sha256(data))
            )
            time.sleep(REQUEST_DELAY_SECONDS)
    return Source(
        id=spec.source_id,
        author=spec.author,
        work=spec.work,
        title=spec.title,
        translator=spec.translator,
        year=spec.year,
        year_note=spec.year_note,
        files=files,
    )


def load_sources() -> list[Source]:
    raw = json.loads(SOURCES_JSON.read_text(encoding="utf-8"))
    return [Source.model_validate(item) for item in raw]


def verify_checksums(sources: list[Source]) -> list[str]:
    """Return the raw files that are missing or whose SHA-256 changed."""
    problems: list[str] = []
    for source in sources:
        for file in source.files:
            path = RAW / file.path
            if not path.exists():
                problems.append(f"missing: {file.path}")
            elif _sha256(path.read_bytes()) != file.sha256:
                problems.append(f"checksum changed: {file.path}")
    return problems


app = typer.Typer(help="Download public domain Stoic texts.")


@app.command()
def main(verify: bool = typer.Option(False, help="Only verify existing files.")) -> None:
    if verify:
        problems = verify_checksums(load_sources())
        for problem in problems:
            typer.echo(problem)
        raise typer.Exit(code=1 if problems else 0)

    headers = {"User-Agent": USER_AGENT}
    with httpx.Client(headers=headers, timeout=TIMEOUT, follow_redirects=True) as client:
        sources = [
            download_gutenberg(client, MEDITATIONS),
            download_wikisource(client, EPICTETUS),
            download_wikisource(client, SENECA),
        ]
    SOURCES_JSON.parent.mkdir(parents=True, exist_ok=True)
    SOURCES_JSON.write_text(
        json.dumps([s.model_dump() for s in sources], indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    total = sum(len(s.files) for s in sources)
    typer.echo(f"Downloaded {total} files, provenance written to {SOURCES_JSON}")
