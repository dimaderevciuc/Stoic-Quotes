"""Filesystem layout of the pipeline data directory."""

from pathlib import Path

PIPELINE_ROOT = Path(__file__).resolve().parents[2]
DATA = PIPELINE_ROOT / "data"
RAW = DATA / "raw"  # downloaded files, gitignored, reproducible from sources.json
SOURCES_JSON = DATA / "sources.json"
PASSAGES = DATA / "passages"  # one JSONL per source, committed
CURATED = DATA / "curated"  # quotes_<work>.jsonl, committed
