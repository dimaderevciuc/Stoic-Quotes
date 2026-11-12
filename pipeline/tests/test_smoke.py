"""Smoke test so CI has something to run before Phase 1 adds real tests."""

import stoic_pipeline


def test_package_imports() -> None:
    assert callable(stoic_pipeline.main)
