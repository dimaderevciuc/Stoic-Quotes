"""Interactive review of curated quotes, one at a time.

Run: uv run stoic-review                       (all files, unreviewed only)
     uv run stoic-review --file quotes_seneca.jsonl --all

Keys: [a]pprove  [e]dit (opens $EDITOR on the JSON)  [r]eject  [s]kip  [q]uit
Approved entries get reviewed=true. Rejected entries move to rejected.jsonl so
they are not proposed again. The file is saved after every action.
"""

from __future__ import annotations

import json
from pathlib import Path

import typer
from pydantic import ValidationError

from stoic_pipeline.jsonl import read_jsonl, write_jsonl
from stoic_pipeline.paths import CURATED
from stoic_pipeline.schema import Quote

REJECTED = CURATED / "rejected.jsonl"


def _show(quote: Quote, position: str) -> None:
    typer.clear()
    typer.secho(f"{position}  {quote.id}  ({quote.citation}, tr. {quote.translator})", bold=True)
    typer.echo(f"\n  \u201c{quote.text}\u201d\n")
    typer.secho(f"  Explanation: {quote.explanation}", fg="cyan")
    typer.echo(f"  Themes: {', '.join(quote.themes)}   Needs: {', '.join(quote.needs)}")
    typer.secho(f"\n  Context: {quote.context}", dim=True)


def _edit(quote: Quote) -> Quote | None:
    """Open the quote as JSON in $EDITOR; return the edited quote or None if unchanged."""
    original = json.dumps(quote.model_dump(), indent=2, ensure_ascii=False)
    edited = typer.edit(original, extension=".json")
    if edited is None or edited == original:
        return None
    try:
        return Quote.model_validate_json(edited)
    except ValidationError as error:
        typer.secho(f"Not saved, invalid entry:\n{error}", fg="red")
        typer.pause()
        return None


def _append_rejected(quote: Quote) -> None:
    existing = read_jsonl(REJECTED, Quote) if REJECTED.exists() else []
    write_jsonl(REJECTED, [*existing, quote])


def review_file(path: Path, include_reviewed: bool) -> bool:
    """Review one file. Returns False if the user chose to quit."""
    quotes = read_jsonl(path, Quote)
    index = 0
    while index < len(quotes):
        quote = quotes[index]
        if quote.reviewed and not include_reviewed:
            index += 1
            continue
        _show(quote, f"[{path.name} {index + 1}/{len(quotes)}]")
        choice = typer.prompt("\n[a]pprove [e]dit [r]eject [s]kip [q]uit", default="s").lower()
        if choice == "a":
            quotes[index] = quote.model_copy(update={"reviewed": True})
        elif choice == "e":
            edited = _edit(quote)
            if edited is not None:
                quotes[index] = edited
            continue  # show the entry again after editing
        elif choice == "r":
            _append_rejected(quotes.pop(index))
            write_jsonl(path, quotes)
            continue
        elif choice == "q":
            return False
        write_jsonl(path, quotes)
        index += 1
    return True


app = typer.Typer(help="Review curated quotes.")


@app.command()
def main(
    file: str | None = typer.Option(None, help="Only this file in data/curated/."),
    all_entries: bool = typer.Option(False, "--all", help="Include already reviewed entries."),
) -> None:
    paths = [CURATED / file] if file else sorted(CURATED.glob("quotes_*.jsonl"))
    for path in paths:
        if not review_file(path, include_reviewed=all_entries):
            break
    typer.echo("Done. Run `uv run stoic-curate validate` to check everything.")
