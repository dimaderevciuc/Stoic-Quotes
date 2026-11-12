"""Crisis detection data: keyword phrases, example sentences, threshold tuning, export.

Run:
    uv run stoic-safety tune     # check keywords + similarity on golden/safety_eval.jsonl
    uv run stoic-safety export   # ../assets/safety/crisis.json and crisis.bin

The app flags text as a crisis if a keyword phrase matches OR the text is close
enough to any crisis example sentence. Both rules err toward flagging: showing
help resources to someone who did not need them costs little; missing someone
who did can cost a life. The Dart code in lib/core/safety repeats normalize()
exactly (tests check it on the same cases).
"""

from __future__ import annotations

import json
import re

import numpy as np
import typer

from stoic_pipeline.charmap import require
from stoic_pipeline.embed import (
    ASSETS,
    DEFAULT_MODEL,
    GOLDEN,
    OnnxEncoder,
    dequantize,
    quantize_rows,
    write_matrix,
)
from stoic_pipeline.paths import DATA, PIPELINE_ROOT

SAFETY = DATA / "safety"
KEYWORDS_FILE = SAFETY / "crisis_keywords.txt"
PHRASES_FILE = SAFETY / "crisis_phrases.txt"
EVAL_FILE = GOLDEN / "safety_eval.jsonl"
REPORT = GOLDEN / "safety_report.md"
OUT = ASSETS.parent / "safety"

# Lowered from the best value on the eval by a safety margin (see `tune`).
SIMILARITY_THRESHOLD = 0.86

_CURLY = str.maketrans({"\u2019": "'", "\u2018": "'", "\u201c": '"', "\u201d": '"'})
_NOT_WORD = re.compile(r"[^a-z0-9']+")


def normalize(text: str) -> str:
    """Lowercase, straight quotes, every non word character a space, padded with spaces."""
    return f" {_NOT_WORD.sub(' ', text.lower().translate(_CURLY)).strip()} "


def _lines(path: str) -> list[str]:
    text = (SAFETY / path).read_text(encoding="utf-8")
    return [line.strip() for line in text.splitlines() if line.strip() and not line.startswith("#")]


def load_keywords() -> list[str]:
    return [normalize(k).strip() for k in _lines(KEYWORDS_FILE.name)]


def load_phrases() -> list[str]:
    return _lines(PHRASES_FILE.name)


def keyword_hit(text: str, keywords: list[str]) -> str | None:
    padded = normalize(text)
    return next((k for k in keywords if f" {k} " in padded), None)


def load_eval() -> list[tuple[str, bool]]:
    rows = [json.loads(line) for line in EVAL_FILE.read_text("utf-8").splitlines() if line]
    return [(r["text"], r["crisis"]) for r in rows]


app = typer.Typer(help="Crisis detection data.")


@app.command("tune")
def tune_cmd() -> None:
    encoder = OnnxEncoder(DEFAULT_MODEL)
    keywords = load_keywords()
    phrases = dequantize(*quantize_rows(encoder.encode(load_phrases())))
    cases = load_eval()
    vectors = encoder.encode([t for t, _ in cases])
    best = (vectors @ phrases.T).max(axis=1)
    kw = [keyword_hit(t, keywords) is not None for t, _ in cases]
    lines = [
        "# Crisis detection",
        "",
        f"{sum(c for _, c in cases)} crisis and {sum(not c for _, c in cases)} non crisis test "
        f"sentences, {len(keywords)} keyword phrases, {len(phrases)} example sentences.",
        "",
        "| Threshold | crisis caught | non crisis flagged |",
        "|---|---|---|",
    ]
    for threshold in np.arange(0.78, 0.921, 0.01):
        flagged = [k or s >= threshold for k, s in zip(kw, best, strict=True)]
        caught = sum(f for f, (_, c) in zip(flagged, cases, strict=True) if c)
        false = sum(f for f, (_, c) in zip(flagged, cases, strict=True) if not c)
        mark = " (chosen)" if abs(threshold - SIMILARITY_THRESHOLD) < 1e-9 else ""
        lines.append(f"| {threshold:.2f}{mark} | {caught} | {false} |")
        typer.echo(lines[-1])
    lines += ["", "| Sentence | crisis | keyword | similarity |", "|---|---|---|---|"]
    for (text, crisis), k, s in zip(cases, kw, best, strict=True):
        lines.append(f"| {text} | {'yes' if crisis else 'no'} | {'yes' if k else ''} | {s:.3f} |")
    REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    typer.echo(f"Wrote {REPORT.relative_to(PIPELINE_ROOT)}")


@app.command("export")
def export_cmd() -> None:
    encoder = OnnxEncoder(DEFAULT_MODEL)
    keywords = load_keywords()
    require(len(set(keywords)) == len(keywords), "duplicate keyword phrases")
    OUT.mkdir(parents=True, exist_ok=True)
    q, scales = quantize_rows(encoder.encode(load_phrases()))
    write_matrix(OUT / "crisis.bin", q, scales)
    config = {"keywords": keywords, "similarity_threshold": SIMILARITY_THRESHOLD}
    (OUT / "crisis.json").write_text(json.dumps(config, indent=1) + "\n", encoding="utf-8")
    # Golden cases for the Dart detector: normalized text and expected keyword hit.
    cases = [
        {"text": t, "normalized": normalize(t), "keyword": keyword_hit(t, keywords)}
        for t, _ in load_eval()
    ]
    (GOLDEN / "safety_parity.json").write_text(
        json.dumps(cases, ensure_ascii=False, indent=1) + "\n", encoding="utf-8"
    )
    typer.echo(f"Wrote {OUT} ({len(keywords)} keywords, {q.shape[0]} example sentences)")
