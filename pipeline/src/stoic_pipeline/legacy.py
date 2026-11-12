"""Trace the app's original 64 quotes (lib/assets/quotes_list.csv) to public domain sources.

Run: uv run stoic-legacy

Writes data/curated/legacy_report.md. For each old quote it shows the closest
passage by the same author in our public domain translations, with a score.
The old file has no sources, and many entries are modern translations or
misattributions, so a human decides which matches are real (see Dima's review).
"""

from __future__ import annotations

import csv
from dataclasses import dataclass

import typer
from rapidfuzz import fuzz, process

from stoic_pipeline.curate import load_passages
from stoic_pipeline.paths import CURATED, PIPELINE_ROOT
from stoic_pipeline.schema import Passage
from stoic_pipeline.text import normalize

LEGACY_CSV = PIPELINE_ROOT.parent / "lib" / "assets" / "quotes_list.csv"
REPORT = CURATED / "legacy_report.md"
STOIC_AUTHORS = {"Marcus Aurelius", "Seneca", "Epictetus"}
# partial_ratio >= 85: the same wording appears in the passage (allowing small edits).
VERBATIM_SCORE = 85
# token_set_ratio >= 60: a different translation of the same idea is plausible.
PLAUSIBLE_SCORE = 60


@dataclass(frozen=True)
class LegacyMatch:
    quote: str
    author: str
    passage: Passage | None
    verbatim_score: float
    topical_score: float

    @property
    def verdict(self) -> str:
        if self.author not in STOIC_AUTHORS:
            return "not a Stoic author in scope"
        if self.verbatim_score >= VERBATIM_SCORE:
            return "traced (same wording)"
        if self.topical_score >= PLAUSIBLE_SCORE:
            return "possible (different translation), check"
        return "not traced"


def read_legacy() -> list[tuple[str, str]]:
    with LEGACY_CSV.open(encoding="utf-8", newline="") as handle:
        return [(row[0], row[1]) for row in csv.reader(handle) if len(row) >= 2]


def match(quote: str, author: str, passages: list[Passage]) -> LegacyMatch:
    candidates = [p for p in passages if p.author == author]
    if not candidates:
        return LegacyMatch(quote, author, None, 0.0, 0.0)
    texts = [normalize(p.text) for p in candidates]
    target = normalize(quote)
    _, verbatim, index = process.extractOne(target, texts, scorer=fuzz.partial_ratio)
    _, topical, topical_index = process.extractOne(target, texts, scorer=fuzz.token_set_ratio)
    best = index if verbatim >= VERBATIM_SCORE else topical_index
    return LegacyMatch(quote, author, candidates[best], verbatim, topical)


app = typer.Typer(help="Trace legacy quotes to public domain passages.")


@app.command()
def main() -> None:
    passages = list(load_passages().values())
    results = [match(q, a, passages) for q, a in read_legacy()]
    lines = ["# Legacy quotes: traceability report", ""]
    for number, result in enumerate(results, start=1):
        lines.append(f"## {number}. {result.author}: {result.verdict}")
        lines.append(f"> {result.quote}")
        if result.passage is not None:
            snippet = result.passage.text[:300]
            lines.append(
                f"\nClosest: `{result.passage.id}` ({result.passage.citation}), "
                f"wording {result.verbatim_score:.0f}, topic {result.topical_score:.0f}"
            )
            lines.append(f"\n{snippet}...")
        lines.append("")
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text("\n".join(lines), encoding="utf-8")
    verdicts: dict[str, int] = {}
    for result in results:
        verdicts[result.verdict] = verdicts.get(result.verdict, 0) + 1
    for verdict, count in verdicts.items():
        typer.echo(f"{count:3}  {verdict}")
    typer.echo(f"Report: {REPORT}")
