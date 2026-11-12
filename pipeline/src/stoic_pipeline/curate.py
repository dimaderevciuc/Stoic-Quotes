"""Validate curated quotes against the source passages.

Run: uv run stoic-curate add drafts.jsonl (turn drafts into full quotes, see Draft)
     uv run stoic-curate validate     (all rules, exits 1 on any problem)
     uv run stoic-curate stats        (counts per author, theme and need)
     uv run stoic-curate passages ma-4 (print passages to curate from, by id prefix)

Curation itself is done by hand (by Claude Code, then reviewed by Dima): quotes are
written to data/curated/quotes_<work>.jsonl. This module makes sure every one of
them is a verbatim, correctly cited excerpt.
"""

from __future__ import annotations

import random
import string
from collections import Counter
from itertools import combinations
from pathlib import Path

import typer
from rapidfuzz import fuzz

from stoic_pipeline.jsonl import read_jsonl, write_jsonl
from stoic_pipeline.paths import CURATED, PASSAGES
from stoic_pipeline.schema import Passage, Quote, StrictModel
from stoic_pipeline.text import clean, normalize, straighten_quotes

# token_set_ratio >= this means two quotes say nearly the same thing in the same words.
NEAR_DUPLICATE_THRESHOLD = 90


def load_passages() -> dict[str, Passage]:
    passages: dict[str, Passage] = {}
    for path in sorted(PASSAGES.glob("*.jsonl")):
        for passage in read_jsonl(path, Passage):
            passages[passage.id] = passage
    return passages


def load_quotes() -> list[Quote]:
    quotes: list[Quote] = []
    for path in sorted(CURATED.glob("quotes_*.jsonl")):
        quotes.extend(read_jsonl(path, Quote))
    return quotes


class Draft(StrictModel):
    """What a curator writes; everything else is copied from the passage."""

    passage_id: str
    text: str
    explanation: str
    themes: list[str]
    needs: list[str]


# Which curated file each work goes to.
CURATED_FILES = {
    "Meditations": "quotes_meditations.jsonl",
    "Discourses": "quotes_discourses.jsonl",
    "Enchiridion": "quotes_enchiridion.jsonl",
    "Moral Letters to Lucilius": "quotes_seneca.jsonl",
    "As a Man Thinketh": "quotes_allen.jsonl",
}


def locate_exact(fragment: str, passage_text: str) -> str | None:
    """Find FRAGMENT in the passage, treating curly and straight quote marks as equal.

    Returns the exact source slice, so stored quotes keep the source's own punctuation.
    Letters, words and case must match exactly; whitespace runs are collapsed first.
    """
    source = clean(passage_text)
    # Straightening quote marks keeps the length, so offsets map 1:1 back to the source.
    start = straighten_quotes(source).find(straighten_quotes(clean(fragment)))
    if start < 0:
        return None
    return source[start : start + len(clean(fragment))]


def quote_id_base(passage_id: str) -> str:
    """ma-4-3 -> ma-4-3, epi-1-1-p3 -> epi-1-1 (Discourses quotes are cited by chapter)."""
    parts = passage_id.split("-")
    if parts[-1].startswith("p") and parts[-1][1:].isdigit():
        parts = parts[:-1]
    return "-".join(parts)


def next_quote_id(base: str, taken: set[str]) -> str:
    for letter in string.ascii_lowercase:
        candidate = f"{base}-{letter}"
        if candidate not in taken:
            return candidate
    raise ValueError(f"more than 26 quotes for {base}")


def draft_to_quote(draft: Draft, passage: Passage, taken: set[str]) -> Quote:
    exact = locate_exact(draft.text, passage.text)
    if exact is None:
        raise ValueError(f"{passage.id}: draft text not found in passage: {draft.text[:60]!r}")
    return Quote(
        id=next_quote_id(quote_id_base(passage.id), taken),
        text=exact,
        author=passage.author,
        work=passage.work,
        citation=passage.citation,
        translator=passage.translator,
        year=passage.year,
        passage_id=passage.id,
        context=passage.text,
        explanation=draft.explanation,
        themes=draft.themes,
        needs=draft.needs,
    )


def add_drafts(drafts: list[Draft], passages: dict[str, Passage]) -> tuple[int, list[str]]:
    """Append drafts to the curated files. Returns (added count, errors)."""
    existing: dict[str, list[Quote]] = {}
    for filename in CURATED_FILES.values():
        path = CURATED / filename
        existing[filename] = read_jsonl(path, Quote) if path.exists() else []
    taken = {q.id for quotes in existing.values() for q in quotes}
    known_texts = {normalize(q.text) for quotes in existing.values() for q in quotes}
    added, errors = 0, []
    for draft in drafts:
        passage = passages.get(draft.passage_id)
        if passage is None:
            errors.append(f"unknown passage {draft.passage_id}")
            continue
        try:
            quote = draft_to_quote(draft, passage, taken)
        except ValueError as error:  # pydantic ValidationError is a ValueError
            errors.append(str(error))
            continue
        if normalize(quote.text) in known_texts:
            continue  # already curated, adding twice would only create a duplicate
        existing[CURATED_FILES[quote.work]].append(quote)
        taken.add(quote.id)
        known_texts.add(normalize(quote.text))
        added += 1
    for filename, quotes in existing.items():
        if quotes:
            write_jsonl(CURATED / filename, quotes)
    return added, errors


def check_against_passage(quote: Quote, passages: dict[str, Passage]) -> list[str]:
    """Problems where a quote disagrees with the passage it claims to come from."""
    passage = passages.get(quote.passage_id)
    if passage is None:
        return [f"{quote.id}: unknown passage_id {quote.passage_id}"]
    problems: list[str] = []
    if clean(quote.context) != clean(passage.text):
        problems.append(f"{quote.id}: context differs from passage {passage.id}")
    if clean(quote.text) not in clean(passage.text):
        problems.append(f"{quote.id}: text is not an exact substring of {passage.id}")
    for field in ("author", "work", "citation", "translator", "year"):
        if getattr(quote, field) != getattr(passage, field):
            problems.append(f"{quote.id}: {field} does not match passage {passage.id}")
    return problems


def find_duplicate_ids(quotes: list[Quote]) -> list[str]:
    counts = Counter(q.id for q in quotes)
    return [f"duplicate id: {quote_id}" for quote_id, n in counts.items() if n > 1]


def find_near_duplicates(quotes: list[Quote]) -> list[str]:
    problems: list[str] = []
    texts = [(q.id, normalize(q.text)) for q in quotes]
    for (id_a, text_a), (id_b, text_b) in combinations(texts, 2):
        if text_a in text_b or text_b in text_a:
            problems.append(f"near duplicate: {id_a} and {id_b} (one contains the other)")
        elif fuzz.token_set_ratio(text_a, text_b) >= NEAR_DUPLICATE_THRESHOLD:
            problems.append(f"near duplicate: {id_a} and {id_b}")
    return problems


def validate(quotes: list[Quote], passages: dict[str, Passage]) -> list[str]:
    problems = find_duplicate_ids(quotes) + find_near_duplicates(quotes)
    for quote in quotes:
        problems.extend(check_against_passage(quote, passages))
    return problems


app = typer.Typer(help="Validate and inspect curated quotes.")


@app.command()
def add(drafts_file: Path) -> None:
    """Turn a JSONL file of drafts into curated quotes."""
    drafts = read_jsonl(drafts_file, Draft)
    added, errors = add_drafts(drafts, load_passages())
    for error in errors:
        typer.echo(f"error: {error}")
    typer.echo(f"{added} added, {len(errors)} errors")
    raise typer.Exit(code=1 if errors else 0)


@app.command("validate")
def validate_command() -> None:
    quotes = load_quotes()
    problems = validate(quotes, load_passages())
    for problem in problems:
        typer.echo(problem)
    typer.echo(f"{len(quotes)} quotes, {len(problems)} problems")
    raise typer.Exit(code=1 if problems else 0)


@app.command()
def stats(samples: int = typer.Option(10, help="Random samples to print.")) -> None:
    quotes = load_quotes()
    typer.echo(f"Total: {len(quotes)} ({sum(q.reviewed for q in quotes)} reviewed)")
    for label, counter in (
        ("Author", Counter(q.author for q in quotes)),
        ("Theme", Counter(t for q in quotes for t in q.themes)),
        ("Need", Counter(n for q in quotes for n in q.needs)),
    ):
        typer.echo(f"\n{label}:")
        for key, count in counter.most_common():
            typer.echo(f"  {key:<20} {count}")
    typer.echo("\nSamples:")
    for quote in random.sample(quotes, min(samples, len(quotes))):
        typer.echo(f"\n[{quote.id}] {quote.citation}\n  {quote.text}\n  -> {quote.explanation}")


@app.command()
def passages(prefix: str, max_chars: int = typer.Option(0, help="Truncate long passages.")) -> None:
    """Print passages whose id starts with PREFIX, for curating."""
    for passage in load_passages().values():
        if passage.id.startswith(prefix):
            text = passage.text[:max_chars] if max_chars else passage.text
            typer.echo(f"## {passage.id} | {passage.citation}\n{text}\n")
