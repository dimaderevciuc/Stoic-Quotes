"""Export the reviewed content for the app: quotes and source credits.

Run: uv run stoic-export   (writes ../assets/content/)

The app reads these read-only JSON files into memory at startup. Only reviewed
quotes are exported, so an unreviewed draft can never reach a phone.
"""

from __future__ import annotations

import json

import typer

from stoic_pipeline.download import load_sources
from stoic_pipeline.embed import load_quotes
from stoic_pipeline.paths import PIPELINE_ROOT

CONTENT = PIPELINE_ROOT.parent / "assets" / "content"


def _origin(url: str) -> str:
    if "gutenberg.org" in url:
        ebook = url.rsplit("/pg", 1)[-1].removesuffix(".txt")
        return f"Project Gutenberg #{ebook}"
    if "wikisource.org" in url:
        return "Wikisource"
    return url


app = typer.Typer(help="Export app content.")


@app.command()
def main() -> None:
    quotes = load_quotes()
    unreviewed = [q.id for q in quotes if not q.reviewed]
    if unreviewed:
        raise typer.BadParameter(
            f"{len(unreviewed)} quotes are not reviewed, e.g. {unreviewed[:3]}"
        )
    CONTENT.mkdir(parents=True, exist_ok=True)
    rows = [
        q.model_dump(
            include={
                "id",
                "text",
                "author",
                "work",
                "citation",
                "translator",
                "year",
                "context",
                "explanation",
                "themes",
                "needs",
            }
        )
        for q in quotes
    ]
    (CONTENT / "quotes.json").write_text(
        json.dumps(rows, ensure_ascii=False, separators=(",", ":")), encoding="utf-8"
    )
    credits = [
        {
            "author": s.author,
            "work": s.work,
            "title": s.title,
            "translator": s.translator,
            "year": s.year,
            "origin": _origin(s.files[0].url),
        }
        for s in load_sources()
    ]
    (CONTENT / "sources.json").write_text(
        json.dumps(credits, ensure_ascii=False, indent=1) + "\n", encoding="utf-8"
    )
    typer.echo(f"Wrote {len(rows)} quotes and {len(credits)} sources to {CONTENT}")
