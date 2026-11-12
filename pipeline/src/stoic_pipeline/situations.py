"""Situation library: validation, vectors and match threshold tuning.

Run:
    uv run stoic-situations validate   # schema, quote ids, taxonomy, no eval leakage
    uv run stoic-situations tune       # sweep the match threshold, write situation_report.md

Matching (PLAN Phase 3 step 4): a situation's vector is the mean of its example
phrase vectors. The user's text is compared with every situation; if the best
one scores at least the threshold, its hand-picked quotes come first, then the
plain quote search fills the rest. Otherwise only the plain search is shown.
"""

from __future__ import annotations

import json
from dataclasses import dataclass

import numpy as np
import typer

from stoic_pipeline.embed import (
    DEFAULT_MODE,
    DEFAULT_MODEL,
    GOLDEN,
    TOP_K,
    EvalCase,
    OnnxEncoder,
    dequantize,
    embed_quotes,
    load_eval,
    load_quotes,
    normalize_rows,
    quantize_rows,
    score,
)
from stoic_pipeline.jsonl import read_jsonl
from stoic_pipeline.paths import DATA, PIPELINE_ROOT
from stoic_pipeline.schema import Situation

SITUATIONS_DIR = DATA / "situations"
SITUATIONS_FILE = SITUATIONS_DIR / "situations.jsonl"
TAXONOMY_FILE = SITUATIONS_DIR / "taxonomy.jsonl"
NEGATIVES_FILE = GOLDEN / "eval_negatives.jsonl"
REPORT = GOLDEN / "situation_report.md"

# Chosen with `tune` (see situation_report.md); the app reads it from config.json.
DEFAULT_THRESHOLD = 0.90


def load_situations() -> list[Situation]:
    return read_jsonl(SITUATIONS_FILE, Situation)


def _repeats(application: str, explanation: str) -> bool:
    """A near copy (small rewording counts too) adds nothing to the card."""
    from rapidfuzz import fuzz

    a, e = application.strip().lower(), explanation.strip().lower()
    return a.rstrip(".") in e or fuzz.ratio(a, e) >= 70


def validate_situations(situations: list[Situation]) -> list[str]:
    """Every rule beyond the schema: links to quotes and taxonomy, no test leakage."""
    problems: list[str] = []
    quotes = {q.id: q for q in load_quotes()}
    quote_ids = set(quotes)
    taxonomy = [json.loads(line) for line in TAXONOMY_FILE.read_text("utf-8").splitlines() if line]
    by_id = {t["id"]: t for t in taxonomy}
    seen: set[str] = set()
    eval_texts = {c.text.lower() for c in load_eval()}
    for s in situations:
        if s.id in seen:
            problems.append(f"{s.id}: duplicate id")
        seen.add(s.id)
        entry = by_id.get(s.id)
        if entry is None:
            problems.append(f"{s.id}: not in taxonomy.jsonl")
        elif (entry["title"], entry["category"], entry["is_sensitive"]) != (
            s.title,
            s.category,
            s.is_sensitive,
        ):
            problems.append(f"{s.id}: title, category or sensitivity differs from the taxonomy")
        problems += [f"{s.id}: unknown quote {q}" for q in s.quote_ids if q not in quote_ids]
        # "How it applies" must add something: not just repeat the card's explanation.
        problems += [
            f"{s.id}: application for {q} repeats its explanation"
            for q, text in s.applications.items()
            if q in quotes and _repeats(text, quotes[q].explanation)
        ]
        # A phrase identical to a test sentence would make the tuning numbers lie.
        problems += [
            f"{s.id}: phrase is an eval sentence: {p!r}"
            for p in s.example_phrases
            if p.lower() in eval_texts
        ]
    problems += [f"{i}: in taxonomy but has no content" for i in by_id if i not in seen]
    return problems


def situation_vectors(encoder: OnnxEncoder, situations: list[Situation]) -> np.ndarray:
    return normalize_rows(
        np.stack([encoder.encode(s.example_phrases).mean(axis=0) for s in situations])
    )


@dataclass(frozen=True)
class Match:
    ranked: list[str]  # quote ids, best first
    situation: str | None  # the shown situation, if any
    best_score: float  # similarity of the best situation, shown or not


def combined_ranking(
    query: np.ndarray,
    docs: np.ndarray,
    quote_ids: list[str],
    sit_vecs: np.ndarray,
    situations: list[Situation],
    threshold: float,
) -> Match:
    plain = [quote_ids[i] for i in np.argsort(-(docs @ query), kind="stable")]
    sims = sit_vecs @ query
    best = int(np.argmax(sims))
    if sims[best] < threshold:
        return Match(plain, None, float(sims[best]))
    picked = situations[best].quote_ids
    return Match(
        picked + [q for q in plain if q not in picked], situations[best].id, float(sims[best])
    )


app = typer.Typer(help="Validate and tune the situation library.")


@app.command("validate")
def validate_cmd() -> None:
    situations = load_situations()
    problems = validate_situations(situations)
    for p in problems:
        typer.echo(p)
    typer.echo(f"{len(situations)} situations, {len(problems)} problems")
    if problems:
        raise typer.Exit(1)


def _negatives() -> list[str]:
    lines = NEGATIVES_FILE.read_text("utf-8").splitlines()
    return [json.loads(line)["text"] for line in lines if line.strip()]


@app.command("tune")
def tune_cmd() -> None:
    """Sweep the threshold on the 50 labeled situations plus off topic sentences."""
    encoder = OnnxEncoder(DEFAULT_MODEL)
    situations = load_situations()
    quotes = load_quotes()
    quote_ids = [q.id for q in quotes]
    # Same int8 vectors as the app, so the numbers match what users get.
    docs = dequantize(*quantize_rows(embed_quotes(encoder, quotes, DEFAULT_MODE)))
    sit_vecs = dequantize(*quantize_rows(situation_vectors(encoder, situations)))
    cases: list[EvalCase] = load_eval()
    queries = encoder.encode([c.text for c in cases])
    negatives = encoder.encode(_negatives())

    plain = score(
        [combined_ranking(q, docs, quote_ids, sit_vecs, situations, 2.0).ranked for q in queries],
        cases,
    )
    lines = [
        "# Situation matching",
        "",
        f"{len(situations)} situations, {len(cases)} labeled test sentences, "
        f"{len(negatives)} off topic sentences. Quotes only (no situations): "
        f"recall@5 {plain.recall:.3f}, hit@5 {plain.hit:.3f}.",
        "",
        "- shown: share of test sentences that get a situation",
        "- right: of those shown, share where it is one of the expected situations",
        "- off topic shown: share of off topic sentences that wrongly get a situation",
        "- recall@5 / hit@5: quote metrics with the situation's quotes first",
        "",
        "| Threshold | shown | right | off topic shown | recall@5 | hit@5 |",
        "|---|---|---|---|---|---|",
    ]
    for threshold in np.arange(0.80, 0.931, 0.01):
        matches = [
            combined_ranking(q, docs, quote_ids, sit_vecs, situations, threshold) for q in queries
        ]
        shown = [(m, c) for m, c in zip(matches, cases, strict=True) if m.situation]
        right = sum(m.situation in c.situations for m, c in shown)
        neg_shown = sum(float((sit_vecs @ n).max()) >= threshold for n in negatives)
        s = score([m.ranked for m in matches], cases)
        mark = " (chosen)" if abs(threshold - DEFAULT_THRESHOLD) < 1e-9 else ""
        lines.append(
            f"| {threshold:.2f}{mark} | {len(shown) / len(cases):.2f} | "
            f"{right / len(shown) if shown else 0:.2f} | {neg_shown / len(negatives):.2f} | "
            f"{s.recall:.3f} | {s.hit:.3f} |"
        )
        typer.echo(lines[-1])
    # Top match per test sentence at the chosen threshold, for a human look.
    lines += [
        "",
        f"## Matches at {DEFAULT_THRESHOLD:.2f}",
        "",
        "| Sentence | Best situation | Score | Shown | Expected |",
        "|---|---|---|---|---|",
    ]
    for q, c in zip(queries, cases, strict=True):
        sims = sit_vecs @ q
        best = int(np.argmax(sims))
        ok = situations[best].id in c.situations
        lines.append(
            f"| {c.text} | {situations[best].id} | {sims[best]:.3f} | "
            f"{'yes' if sims[best] >= DEFAULT_THRESHOLD else 'no'} | {'yes' if ok else 'no'} |"
        )
    REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    typer.echo(f"Wrote {REPORT.relative_to(PIPELINE_ROOT)} (top {TOP_K})")
