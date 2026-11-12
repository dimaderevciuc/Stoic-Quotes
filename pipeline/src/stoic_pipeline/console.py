"""Terminal helpers that typer no longer provides (it dropped click in 0.29)."""

from __future__ import annotations

import os
import shlex
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

# Tried in order when $VISUAL and $EDITOR are not set.
FALLBACK_EDITORS = ("nano", "vim", "vi")


def clear_screen() -> None:
    """Clear the terminal with ANSI codes (no shell command needed)."""
    if sys.stdout.isatty():
        sys.stdout.write("\033[2J\033[H")
        sys.stdout.flush()


def pause(message: str = "Press Enter to continue...") -> None:
    input(message)


def find_editor() -> list[str]:
    """The editor command as an argument list, e.g. ['code', '--wait']."""
    for variable in ("VISUAL", "EDITOR"):
        value = os.environ.get(variable, "").strip()
        if value:
            return shlex.split(value)
    for name in FALLBACK_EDITORS:
        if shutil.which(name):
            return [name]
    raise RuntimeError("No editor found. Set $EDITOR, for example: export EDITOR=nano")


def edit_text(text: str, suffix: str = ".txt") -> str:
    """Open TEXT in the user's editor and return the saved result."""
    with tempfile.NamedTemporaryFile("w", suffix=suffix, delete=False, encoding="utf-8") as tmp:
        tmp.write(text)
        path = Path(tmp.name)
    try:
        # Argument list, no shell: the file path cannot be interpreted as a command.
        subprocess.run([*find_editor(), str(path)], check=True)  # noqa: S603
        return path.read_text(encoding="utf-8")
    finally:
        path.unlink(missing_ok=True)
