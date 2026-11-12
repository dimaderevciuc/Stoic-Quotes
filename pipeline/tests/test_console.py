"""Editor helper used by the review CLI."""

from pathlib import Path

import pytest

from stoic_pipeline.console import edit_text, find_editor


def test_edit_text_returns_what_the_editor_saved(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    editor = tmp_path / "editor.sh"
    editor.write_text('#!/bin/sh\necho "edited" > "$1"\n', encoding="utf-8")
    editor.chmod(0o755)
    monkeypatch.setenv("EDITOR", str(editor))
    monkeypatch.delenv("VISUAL", raising=False)

    assert edit_text("original").strip() == "edited"


def test_editor_with_arguments_is_split(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("VISUAL", "code --wait")
    assert find_editor() == ["code", "--wait"]
