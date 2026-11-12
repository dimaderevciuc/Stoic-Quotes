"""Read and write JSON Lines files of pydantic models."""

from collections.abc import Iterable
from pathlib import Path

from pydantic import BaseModel


def write_jsonl(path: Path, items: Iterable[BaseModel]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [item.model_dump_json() for item in items]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def read_jsonl[T: BaseModel](path: Path, model: type[T]) -> list[T]:
    lines = path.read_text(encoding="utf-8").splitlines()
    return [model.model_validate_json(line) for line in lines if line.strip()]
