"""Embed the corpus with Model2Vec, compare models, and export for the app.

Run:
    uv run stoic-embed eval      # compare models and document texts on the 50 situations
    uv run stoic-embed export    # write the chosen model and vectors to assets/embedding/

Model2Vec inference, as implemented in model2vec 0.10 (StaticModel.encode):
tokenize with the HF tokenizer without special tokens, drop [UNK] ids, truncate to
max_length tokens, average the token vectors, then L2 normalize. The app repeats
exactly these steps in Dart, so the export only needs the vocabulary, the matrix
and a few tokenizer settings.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path
from typing import TYPE_CHECKING

import numpy as np
import typer
from pydantic import BaseModel, ConfigDict

from stoic_pipeline.charmap import char_tables, require
from stoic_pipeline.curate import CURATED_FILES
from stoic_pipeline.jsonl import read_jsonl
from stoic_pipeline.paths import CURATED, DATA, PIPELINE_ROOT
from stoic_pipeline.schema import Quote

if TYPE_CHECKING:
    from model2vec import StaticModel

GOLDEN = DATA / "golden"
EVAL_FILE = GOLDEN / "eval_situations.jsonl"
PARITY_FILE = GOLDEN / "parity.json"
EVAL_REPORT = GOLDEN / "eval_report.md"
ASSETS = PIPELINE_ROOT.parent / "assets" / "embedding"

CANDIDATES = (
    "minishlab/potion-base-8M",
    "minishlab/blink-8M",
    "minishlab/potion-base-32M",
    "minishlab/potion-retrieval-32M",
)

# What each quote is represented by, as weights for (explanation, text, tags). Users
# write in modern English, so the plain explanation is expected to match them better
# than the 19th century wording; the eval measures it instead of assuming it. Tags are
# the theme and need words ("anger forgiveness calm"), which add a little recall.
DOC_MODES: dict[str, tuple[float, float, float]] = {
    "text": (0.0, 1.0, 0.0),
    "explanation": (1.0, 0.0, 0.0),
    "average": (1.0, 1.0, 0.0),
    "weighted": (2.0, 1.0, 1.0),
}
DEFAULT_MODEL = "minishlab/potion-base-8M"
DEFAULT_MODE = "weighted"

TOP_K = 5
MAGIC = b"SQE1"  # file format tag, bump if the layout below changes


class EvalCase(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid")
    id: str
    text: str
    relevant: list[str]


@dataclass(frozen=True)
class Scores:
    recall: float  # share of the (up to 5) expected quotes found in the top 5
    hit: float  # share of situations with at least one expected quote in the top 5
    mrr: float  # mean reciprocal rank of the first expected quote


def load_quotes() -> list[Quote]:
    quotes: list[Quote] = []
    for name in sorted(CURATED_FILES.values()):
        quotes.extend(read_jsonl(CURATED / name, Quote))
    return quotes


def load_eval() -> list[EvalCase]:
    return read_jsonl(EVAL_FILE, EvalCase)


def normalize_rows(matrix: np.ndarray) -> np.ndarray:
    norms = np.linalg.norm(matrix, axis=1, keepdims=True)
    return matrix / np.maximum(norms, 1e-12)


def tag_words(quote: Quote) -> str:
    return " ".join(quote.themes + quote.needs).replace("-", " ")


def embed_quotes(model: StaticModel, quotes: list[Quote], mode: str) -> np.ndarray:
    """Weighted mean of the separately normalized parts, so a long part cannot drown a short one."""
    w_expl, w_text, w_tags = DOC_MODES[mode]
    parts = (
        (w_expl, [q.explanation for q in quotes]),
        (w_text, [q.text for q in quotes]),
        (w_tags, [tag_words(q) for q in quotes]),
    )
    total = np.zeros((len(quotes), model.dim), dtype=np.float32)
    for weight, texts in parts:
        if weight:
            total += weight * normalize_rows(np.asarray(model.encode(texts), dtype=np.float32))
    return normalize_rows(total)


def top_k(query: np.ndarray, docs: np.ndarray, k: int = TOP_K) -> list[int]:
    scores = docs @ query
    return [int(i) for i in np.argsort(-scores, kind="stable")[:k]]


def score(ranked: list[list[str]], cases: list[EvalCase]) -> Scores:
    recalls, hits, rranks = [], [], []
    for ids, case in zip(ranked, cases, strict=True):
        relevant = set(case.relevant)
        found = [i for i in ids[:TOP_K] if i in relevant]
        recalls.append(len(found) / min(TOP_K, len(relevant)))
        hits.append(1.0 if found else 0.0)
        first = next((rank for rank, i in enumerate(ids, 1) if i in relevant), None)
        rranks.append(1.0 / first if first else 0.0)
    return Scores(float(np.mean(recalls)), float(np.mean(hits)), float(np.mean(rranks)))


def rank_all(query_vectors: np.ndarray, docs: np.ndarray, ids: list[str]) -> list[list[str]]:
    # Rank everything (not only the top 5) so MRR sees ranks beyond 5.
    order = np.argsort(-(query_vectors @ docs.T), axis=1, kind="stable")
    return [[ids[i] for i in row] for row in order]


def quantize_rows(matrix: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Symmetric int8 per row: row ~= q * scale, with scale = max(|row|) / 127."""
    scales = np.abs(matrix).max(axis=1) / 127.0
    scales = np.where(scales == 0, 1.0, scales).astype(np.float32)
    q = np.clip(np.rint(matrix / scales[:, None]), -127, 127).astype(np.int8)
    return q, scales


def dequantize(q: np.ndarray, scales: np.ndarray) -> np.ndarray:
    return q.astype(np.float32) * scales[:, None]


def quantized_model(model: StaticModel) -> StaticModel:
    """Copy of the model whose matrix went through the int8 round trip the app uses."""
    from model2vec import StaticModel

    q, scales = quantize_rows(np.asarray(model.embedding, dtype=np.float32))
    return StaticModel(
        vectors=dequantize(q, scales),
        tokenizer=model.tokenizer,
        config=dict(model.config),
        normalize=True,
        max_length=model.max_length,
    )


def vocab_size_mb(model: StaticModel) -> float:
    rows, dim = model.embedding.shape
    return (rows * dim + rows * 4) / 1e6  # int8 matrix plus one float32 scale per row


app = typer.Typer(help="Embed quotes and export the model for the app.")


@app.command("eval")
def eval_cmd() -> None:
    """Compare every candidate model and document mode, write eval_report.md."""
    from model2vec import StaticModel

    quotes = load_quotes()
    ids = [q.id for q in quotes]
    cases = load_eval()
    lines = [
        "# Retrieval eval",
        "",
        f"{len(cases)} situations, {len(quotes)} quotes. recall@5 counts the expected "
        "quotes found in the top 5 (out of at most 5); hit@5 is the share of situations "
        "with at least one; int8 is the same model after the app's quantization.",
        "",
        "| Model | Size (int8) | Quote text | recall@5 | hit@5 | MRR |",
        "|---|---|---|---|---|---|",
    ]
    for name in CANDIDATES:
        model = StaticModel.from_pretrained(name)
        queries = normalize_rows(np.asarray(model.encode([c.text for c in cases]), np.float32))
        for mode in DOC_MODES:
            docs = embed_quotes(model, quotes, mode)
            s = score(rank_all(queries, docs, ids), cases)
            lines.append(
                f"| {name} | {vocab_size_mb(model):.1f} MB | {mode} | "
                f"{s.recall:.3f} | {s.hit:.3f} | {s.mrr:.3f} |"
            )
            typer.echo(lines[-1])
        # The app quantizes the token matrix and the quote vectors: measure what that costs.
        qmodel = quantized_model(model)
        qq = normalize_rows(np.asarray(qmodel.encode([c.text for c in cases]), np.float32))
        dq = dequantize(*quantize_rows(embed_quotes(model, quotes, DEFAULT_MODE)))
        s = score(rank_all(qq, dq, ids), cases)
        lines.append(
            f"| {name}, int8 as in the app | | {DEFAULT_MODE} | "
            f"{s.recall:.3f} | {s.hit:.3f} | {s.mrr:.3f} |"
        )
        typer.echo(lines[-1])
    EVAL_REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    typer.echo(f"Wrote {EVAL_REPORT.relative_to(PIPELINE_ROOT)}")


def write_matrix(path: Path, q: np.ndarray, scales: np.ndarray) -> None:
    """Layout (little endian): MAGIC, u32 rows, u32 dim, f32 scales[rows], i8 q[rows*dim]."""
    rows, dim = q.shape
    with path.open("wb") as f:
        f.write(MAGIC)
        f.write(np.array([rows, dim], dtype="<u4").tobytes())
        f.write(scales.astype("<f4").tobytes())
        f.write(q.astype(np.int8).tobytes())


def read_matrix(path: Path) -> tuple[np.ndarray, np.ndarray]:
    data = path.read_bytes()
    require(data[:4] == MAGIC, f"{path.name}: unknown format")
    rows, dim = (int(v) for v in np.frombuffer(data, dtype="<u4", count=2, offset=4))
    scales = np.frombuffer(data, dtype="<f4", count=rows, offset=12)
    q = np.frombuffer(data, dtype=np.int8, count=rows * dim, offset=12 + 4 * rows)
    return q.reshape(rows, dim), scales


@app.command("export")
def export_cmd(
    model_name: str = typer.Option(DEFAULT_MODEL, "--model"),
    mode: str = typer.Option(DEFAULT_MODE, "--mode"),
) -> None:
    """Write tokenizer tables, the int8 matrix and the quote vectors to assets/embedding/."""
    from model2vec import StaticModel

    if mode not in DOC_MODES:
        raise typer.BadParameter(f"mode must be one of {sorted(DOC_MODES)}")
    model = StaticModel.from_pretrained(model_name)
    quotes = load_quotes()
    ASSETS.mkdir(parents=True, exist_ok=True)

    tokenizer = json.loads(model.tokenizer.to_str())
    require(tokenizer["normalizer"]["type"] == "BertNormalizer", "unexpected tokenizer layout")
    require(tokenizer["pre_tokenizer"]["type"] == "BertPreTokenizer", "unexpected tokenizer layout")
    require(tokenizer["model"]["type"] == "WordPiece", "unexpected tokenizer layout")
    vocab: dict[str, int] = tokenizer["model"]["vocab"]
    tokens = sorted(vocab, key=vocab.__getitem__)
    require([vocab[t] for t in tokens] == list(range(len(tokens))), "vocab ids must be dense")
    require(
        all(t and "\n" not in t and "\r" not in t for t in tokens),
        "vocab.txt is one non empty token per line",
    )
    (ASSETS / "vocab.txt").write_text("\n".join(tokens) + "\n", encoding="utf-8")

    q, scales = quantize_rows(np.asarray(model.embedding, dtype=np.float32))
    write_matrix(ASSETS / "tokens.bin", q, scales)
    dq, dscales = quantize_rows(embed_quotes(model, quotes, mode))
    write_matrix(ASSETS / "quotes.bin", dq, dscales)

    (ASSETS / "chars.json").write_text(
        json.dumps(char_tables(model.tokenizer), separators=(",", ":"), ensure_ascii=True),
        encoding="utf-8",
    )
    config = {
        "model": model_name,
        "doc_mode": mode,
        "unk_id": model.unk_token_id,
        "continuing_subword_prefix": tokenizer["model"]["continuing_subword_prefix"],
        "max_input_chars_per_word": tokenizer["model"]["max_input_chars_per_word"],
        "max_length": model.max_length,
        "median_token_length": model.median_token_length,
        "quote_ids": [quote.id for quote in quotes],
    }
    (ASSETS / "config.json").write_text(json.dumps(config, indent=1) + "\n", encoding="utf-8")
    sizes = {p.name: p.stat().st_size / 1e6 for p in sorted(ASSETS.iterdir())}
    for name, mb in sizes.items():
        typer.echo(f"  {name:12} {mb:7.2f} MB")
    typer.echo(f"  total        {sum(sizes.values()):7.2f} MB")


# Edge cases for the tokenizer next to realistic inputs: accents, curly quotes,
# CJK, emoji, control and zero width characters, a word over 100 characters, and
# an input long enough to hit both truncation limits.
PARITY_EXTRA = (
    "Ça va? Naïve café résumé, İstanbul and ÆSIR.",
    "\u201cI\u2019m fine,\u201d she said \u2014 but she wasn\u2019t\u2026",
    "Work stress 東京 😤😤 can't sleep!!!",
    "tab\there\nnew line\r\x00 zero\u200bwidth \ufeffbom",
    "supercalifragilistic" * 6 + " is one very long word",
    "I'm ANXIOUS about my EXAMS. Help???",
    "12345 3.14 #hashtag @someone e-mail: a_b@c.de",
    "",
    "   ",
    "why does everyone leave me " * 200,
)


@app.command("parity")
def parity_cmd() -> None:
    """Write golden/parity.json from the exported assets, for the Dart tests."""
    from model2vec import StaticModel

    config = json.loads((ASSETS / "config.json").read_text(encoding="utf-8"))
    model = StaticModel.from_pretrained(config["model"])
    q, scales = read_matrix(ASSETS / "tokens.bin")
    # Query side exactly as the app computes it: int8 token matrix, mean, normalize.
    app_model = StaticModel(
        vectors=dequantize(q, scales),
        tokenizer=model.tokenizer,
        config=dict(model.config),
        normalize=True,
        max_length=model.max_length,
    )
    docs = dequantize(*read_matrix(ASSETS / "quotes.bin"))
    ids: list[str] = config["quote_ids"]
    sentences = [c.text for c in load_eval()[:20]] + list(PARITY_EXTRA)
    cases = []
    for sentence in sentences:
        query = np.asarray(app_model.encode([sentence])[0], dtype=np.float32)
        token_ids = app_model.tokenize([truncate_chars(app_model, sentence)])[0]
        scores = docs @ query
        best = top_k(query, docs)
        cases.append(
            {
                "text": sentence,
                "token_ids": token_ids,
                "top5": [{"id": ids[i], "score": round(float(scores[i]), 6)} for i in best],
            }
        )
    GOLDEN.mkdir(parents=True, exist_ok=True)
    # One case per line keeps the file readable and the diffs small.
    body = ",\n".join(json.dumps(c, ensure_ascii=False) for c in cases)
    PARITY_FILE.write_text(f"[\n{body}\n]\n", encoding="utf-8")
    typer.echo(f"Wrote {len(cases)} cases to {PARITY_FILE.relative_to(PIPELINE_ROOT)}")


def truncate_chars(model: StaticModel, sentence: str) -> str:
    # encode() cuts the string to max_length * median_token_length characters before
    # tokenizing (a cheap guard against huge inputs); tokenize() alone does not.
    if model.max_length is None:
        return sentence
    return sentence[: model.max_length * model.median_token_length]
