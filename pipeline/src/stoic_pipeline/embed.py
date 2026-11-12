"""Embed the corpus with a small sentence transformer (ONNX), compare models, export.

Run:
    uv run stoic-embed eval      # compare models on the 50 labeled situations
    uv run stoic-embed export    # model, tokenizer tables and quote vectors -> assets/embedding/
    uv run stoic-embed parity    # golden/parity.json, checked by the Dart tests

The app runs the very same int8 ONNX file through ONNX Runtime and tokenizes in
Dart, so a query embedding on the phone equals the Python one:
tokens = [CLS] + WordPiece(text)[:max_length - 2] + [SEP], vector = mean of the
model's last hidden states, then L2 normalize. Quote vectors are computed here
once and shipped as int8.
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from functools import cached_property
from pathlib import Path

import numpy as np
import typer
from pydantic import BaseModel, ConfigDict

from stoic_pipeline.charmap import char_tables, require
from stoic_pipeline.curate import CURATED_FILES
from stoic_pipeline.jsonl import read_jsonl
from stoic_pipeline.paths import CURATED, DATA, PIPELINE_ROOT
from stoic_pipeline.schema import Quote

GOLDEN = DATA / "golden"
EVAL_FILE = GOLDEN / "eval_situations.jsonl"
PARITY_FILE = GOLDEN / "parity.json"
EVAL_REPORT = GOLDEN / "eval_report.md"
ASSETS = PIPELINE_ROOT.parent / "assets" / "embedding"

# User text is a few sentences; 256 tokens (about 190 words) covers it and keeps a
# phone inference fast. The tokenizer files ship with 128, so it is set explicitly.
MAX_LENGTH = 256
TOP_K = 5
MAGIC = b"SQE1"  # matrix file format tag, bump if write_matrix changes


@dataclass(frozen=True)
class ModelSpec:
    repo: str
    revision: str  # pinned commit, so a changed upload cannot change the app silently
    onnx_file: str = "onnx/model_quantized.onnx"  # int8 weights, what the app ships
    license: str = ""


GTE_SMALL = ModelSpec("Xenova/gte-small", "5927d1727bb12db490052a1b33265ad78058de08", license="MIT")
CANDIDATES = (
    GTE_SMALL,
    ModelSpec(
        "Xenova/all-MiniLM-L6-v2", "751bff37182d3f1213fa05d7196b954e230abad9", license="Apache-2.0"
    ),
    ModelSpec(
        "Xenova/all-MiniLM-L12-v2", "beeb2e4b69e95f188a15cc2e90d09fd035dac229", license="Apache-2.0"
    ),
)
DEFAULT_MODEL = GTE_SMALL

# What each quote is represented by, as weights for (explanation, text, tags). Users
# write in modern English, so the plain explanation matches them best; the quote
# text and the theme/need words ("anger forgiveness calm") add a little recall.
DOC_MODES: dict[str, tuple[float, float, float]] = {
    "text": (0.0, 1.0, 0.0),
    "explanation": (1.0, 0.0, 0.0),
    "weighted": (2.0, 1.0, 1.0),
}
DEFAULT_MODE = "weighted"


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


class OnnxEncoder:
    """Mean pooled, normalized sentence vectors from an ONNX BERT model."""

    def __init__(self, spec: ModelSpec) -> None:
        from huggingface_hub import hf_hub_download

        self.spec = spec
        self.model_path = Path(hf_hub_download(spec.repo, spec.onnx_file, revision=spec.revision))
        self.tokenizer_path = Path(
            hf_hub_download(spec.repo, "tokenizer.json", revision=spec.revision)
        )

    @cached_property
    def tokenizer(self):  # noqa: ANN201 (tokenizers has no type stubs)
        from tokenizers import Tokenizer

        tok = Tokenizer.from_file(str(self.tokenizer_path))
        tok.no_padding()
        tok.enable_truncation(MAX_LENGTH)
        return tok

    @cached_property
    def session(self):  # noqa: ANN201
        import onnxruntime as ort

        return ort.InferenceSession(str(self.model_path), providers=["CPUExecutionProvider"])

    def token_ids(self, text: str) -> list[int]:
        return list(self.tokenizer.encode(text).ids)

    def encode_ids(self, ids: list[int]) -> np.ndarray:
        """One sentence, no padding: exactly what the app feeds ONNX Runtime."""
        input_ids = np.array([ids], dtype=np.int64)
        feed = {
            "input_ids": input_ids,
            "attention_mask": np.ones_like(input_ids),
            "token_type_ids": np.zeros_like(input_ids),
        }
        hidden = self.session.run(["last_hidden_state"], feed)[0][0]
        return normalize_rows(hidden.mean(axis=0, keepdims=True).astype(np.float32))[0]

    def encode(self, texts: list[str]) -> np.ndarray:
        # One at a time on purpose: padding would change nothing after masking, but
        # this way the eval runs the identical code path as parity and the app.
        return np.stack([self.encode_ids(self.token_ids(t)) for t in texts])

    def file_sha256(self) -> str:
        return hashlib.sha256(self.model_path.read_bytes()).hexdigest()


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


def embed_quotes(encoder: OnnxEncoder, quotes: list[Quote], mode: str) -> np.ndarray:
    """Weighted mean of the separately normalized parts, so a long part cannot drown a short one."""
    w_expl, w_text, w_tags = DOC_MODES[mode]
    parts = (
        (w_expl, [q.explanation for q in quotes]),
        (w_text, [q.text for q in quotes]),
        (w_tags, [tag_words(q) for q in quotes]),
    )
    total: np.ndarray | None = None
    for weight, texts in parts:
        if weight:
            part = weight * encoder.encode(texts)
            total = part if total is None else total + part
    require(total is not None, f"mode {mode} has no parts")
    return normalize_rows(total)  # type: ignore[arg-type]


def top_k(query: np.ndarray, docs: np.ndarray, k: int = TOP_K) -> list[int]:
    scores = docs @ query
    return [int(i) for i in np.argsort(-scores, kind="stable")[:k]]


def rank_all(query_vectors: np.ndarray, docs: np.ndarray, ids: list[str]) -> list[list[str]]:
    # Rank everything (not only the top 5) so MRR sees ranks beyond 5.
    order = np.argsort(-(query_vectors @ docs.T), axis=1, kind="stable")
    return [[ids[i] for i in row] for row in order]


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


def quantize_rows(matrix: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Symmetric int8 per row: row ~= q * scale, with scale = max(|row|) / 127."""
    scales = np.abs(matrix).max(axis=1) / 127.0
    scales = np.where(scales == 0, 1.0, scales).astype(np.float32)
    q = np.clip(np.rint(matrix / scales[:, None]), -127, 127).astype(np.int8)
    return q, scales


def dequantize(q: np.ndarray, scales: np.ndarray) -> np.ndarray:
    return q.astype(np.float32) * scales[:, None]


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


app = typer.Typer(help="Embed quotes and export the model for the app.")

# Measured before the switch to ONNX (Model2Vec static embeddings, run on
# 2026-11-12 with the same 50 situations and the weighted mode). Kept so the
# reason for the switch stays visible.
STATIC_HISTORY = """
## Earlier: Model2Vec static embeddings (replaced)

| Model | Size (int8) | recall@5 | hit@5 | MRR |
|---|---|---|---|---|
| minishlab/potion-base-8M | 7.7 MB | 0.274 | 0.640 | 0.512 |
| minishlab/blink-8M | 7.8 MB | 0.246 | 0.700 | 0.542 |
| minishlab/potion-base-32M | 32.6 MB | 0.290 | 0.660 | 0.522 |
| minishlab/potion-retrieval-32M | 32.6 MB | 0.190 | 0.600 | 0.445 |
"""


@app.command("eval")
def eval_cmd() -> None:
    """Compare the candidate models and document modes, write eval_report.md."""
    quotes = load_quotes()
    ids = [q.id for q in quotes]
    cases = load_eval()
    lines = [
        "# Retrieval eval",
        "",
        f"{len(cases)} situations, {len(quotes)} quotes. recall@5 counts the expected "
        "quotes found in the top 5 (out of at most 5); hit@5 is the share of situations "
        "with at least one. Every row uses the int8 ONNX file the app ships; the "
        '"as in the app" row also quantizes the quote vectors to int8.',
        "",
        "| Model | ONNX size | Quote text | recall@5 | hit@5 | MRR |",
        "|---|---|---|---|---|---|",
    ]
    for spec in CANDIDATES:
        encoder = OnnxEncoder(spec)
        size = f"{encoder.model_path.stat().st_size / 1e6:.1f} MB"
        queries = encoder.encode([c.text for c in cases])
        for mode in DOC_MODES:
            docs = embed_quotes(encoder, quotes, mode)
            s = score(rank_all(queries, docs, ids), cases)
            lines.append(
                f"| {spec.repo} | {size} | {mode} | {s.recall:.3f} | {s.hit:.3f} | {s.mrr:.3f} |"
            )
            typer.echo(lines[-1])
            if mode == DEFAULT_MODE:
                s = score(rank_all(queries, dequantize(*quantize_rows(docs)), ids), cases)
                lines.append(
                    f"| {spec.repo}, as in the app | | {mode} | "
                    f"{s.recall:.3f} | {s.hit:.3f} | {s.mrr:.3f} |"
                )
                typer.echo(lines[-1])
    EVAL_REPORT.write_text("\n".join(lines) + "\n" + STATIC_HISTORY, encoding="utf-8")
    typer.echo(f"Wrote {EVAL_REPORT.relative_to(PIPELINE_ROOT)}")


def special_tokens(tokenizer_json: dict) -> dict[str, int]:
    return {t["content"]: t["id"] for t in tokenizer_json["added_tokens"] if t["special"]}


@app.command("export")
def export_cmd(mode: str = typer.Option(DEFAULT_MODE, "--mode")) -> None:
    """Write the ONNX model, tokenizer tables and quote vectors to assets/embedding/."""
    if mode not in DOC_MODES:
        raise typer.BadParameter(f"mode must be one of {sorted(DOC_MODES)}")
    spec = DEFAULT_MODEL
    encoder = OnnxEncoder(spec)
    quotes = load_quotes()
    tokenizer = json.loads(encoder.tokenizer_path.read_text(encoding="utf-8"))
    require(tokenizer["normalizer"]["type"] == "BertNormalizer", "unexpected normalizer")
    require(tokenizer["pre_tokenizer"]["type"] == "BertPreTokenizer", "unexpected pre-tokenizer")
    require(tokenizer["model"]["type"] == "WordPiece", "unexpected tokenizer model")
    require(tokenizer["post_processor"]["type"] == "TemplateProcessing", "unexpected template")
    specials = special_tokens(tokenizer)
    require(all(k in specials for k in ("[CLS]", "[SEP]", "[UNK]")), "missing special tokens")

    vocab: dict[str, int] = tokenizer["model"]["vocab"]
    tokens = sorted(vocab, key=vocab.__getitem__)
    require([vocab[t] for t in tokens] == list(range(len(tokens))), "vocab ids must be dense")
    require(
        all(t and "\n" not in t and "\r" not in t for t in tokens),
        "vocab.txt is one non empty token per line",
    )

    ASSETS.mkdir(parents=True, exist_ok=True)
    # Old exports: a previous model file or the replaced Model2Vec matrix.
    for stale in [*ASSETS.glob("model-*.onnx"), ASSETS / "tokens.bin"]:
        stale.unlink(missing_ok=True)
    sha = encoder.file_sha256()
    # The hash in the name matters: the ONNX plugin caches the extracted model by
    # file name, so a new model must get a new name or phones keep the old one.
    onnx_name = f"model-{sha[:12]}.onnx"
    (ASSETS / onnx_name).write_bytes(encoder.model_path.read_bytes())
    (ASSETS / "vocab.txt").write_text("\n".join(tokens) + "\n", encoding="utf-8")
    from tokenizers import Tokenizer

    raw_tokenizer = Tokenizer.from_file(str(encoder.tokenizer_path))
    (ASSETS / "chars.json").write_text(
        json.dumps(char_tables(raw_tokenizer), separators=(",", ":"), ensure_ascii=True),
        encoding="utf-8",
    )
    dq, dscales = quantize_rows(embed_quotes(encoder, quotes, mode))
    write_matrix(ASSETS / "quotes.bin", dq, dscales)

    config = {
        "model": spec.repo,
        "revision": spec.revision,
        "license": spec.license,
        "onnx_file": onnx_name,
        "onnx_sha256": sha,
        "doc_mode": mode,
        "max_length": MAX_LENGTH,
        "special_tokens": specials,
        "cls_id": specials["[CLS]"],
        "sep_id": specials["[SEP]"],
        "unk_id": specials["[UNK]"],
        "continuing_subword_prefix": tokenizer["model"]["continuing_subword_prefix"],
        "max_input_chars_per_word": tokenizer["model"]["max_input_chars_per_word"],
        "quote_ids": [quote.id for quote in quotes],
    }
    (ASSETS / "config.json").write_text(json.dumps(config, indent=1) + "\n", encoding="utf-8")
    sizes = {p.name: p.stat().st_size / 1e6 for p in sorted(ASSETS.iterdir())}
    for name, mb in sizes.items():
        typer.echo(f"  {name:24} {mb:7.2f} MB")
    typer.echo(f"  {'total':24} {sum(sizes.values()):7.2f} MB")


# Edge cases for the tokenizer next to realistic inputs: accents, curly quotes,
# CJK, emoji, control and zero width characters, a word over 100 characters,
# special token strings typed by a user, and an input past the token limit.
PARITY_EXTRA = (
    "Ça va? Naïve café résumé, İstanbul and ÆSIR.",
    "\u201cI\u2019m fine,\u201d she said \u2014 but she wasn\u2019t\u2026",
    "Work stress 東京 😤😤 can't sleep!!!",
    "tab\there\nnew line\r\x00 zero\u200bwidth \ufeffbom",
    "supercalifragilistic" * 6 + " is one very long word",
    "I'm ANXIOUS about my EXAMS. Help??? [CLS] [MASK] x[SEP]y [unk]",
    "12345 3.14 #hashtag @someone e-mail: a_b@c.de",
    "",
    "   ",
    "why does everyone leave me " * 60,
)


@app.command("parity")
def parity_cmd() -> None:
    """Write golden/parity.json from the exported assets, for the Dart tests."""
    config = json.loads((ASSETS / "config.json").read_text(encoding="utf-8"))
    require(config["model"] == DEFAULT_MODEL.repo, "assets were exported from another model")
    encoder = OnnxEncoder(DEFAULT_MODEL)
    require(encoder.file_sha256() == config["onnx_sha256"], "model file changed since export")
    docs = dequantize(*read_matrix(ASSETS / "quotes.bin"))
    ids: list[str] = config["quote_ids"]
    sentences = [c.text for c in load_eval()[:20]] + list(PARITY_EXTRA)
    cases = []
    for sentence in sentences:
        token_ids = encoder.token_ids(sentence)
        query = encoder.encode_ids(token_ids)
        scores = docs @ query
        cases.append(
            {
                "text": sentence,
                "token_ids": token_ids,
                "top5": [
                    {"id": ids[i], "score": round(float(scores[i]), 6)} for i in top_k(query, docs)
                ],
                # The Python query vector, so the Dart search can be checked on its own.
                "query": [round(float(v), 6) for v in query],
            }
        )
    # One case per line keeps the file readable and the diffs small.
    body = ",\n".join(json.dumps(c, ensure_ascii=False) for c in cases)
    PARITY_FILE.write_text(f"[\n{body}\n]\n", encoding="utf-8")
    typer.echo(f"Wrote {len(cases)} cases to {PARITY_FILE.relative_to(PIPELINE_ROOT)}")


@app.command("fetch")
def fetch_cmd() -> None:
    """Download the model named in config.json into assets/ (it is not in git)."""
    config = json.loads((ASSETS / "config.json").read_text(encoding="utf-8"))
    spec = next((s for s in CANDIDATES if s.repo == config["model"]), None)
    require(spec is not None and spec.revision == config["revision"], "unknown model in config")
    encoder = OnnxEncoder(spec)  # type: ignore[arg-type]
    require(encoder.file_sha256() == config["onnx_sha256"], "downloaded model has a wrong SHA-256")
    (ASSETS / config["onnx_file"]).write_bytes(encoder.model_path.read_bytes())
    typer.echo(f"Wrote {config['onnx_file']} (SHA-256 verified)")
