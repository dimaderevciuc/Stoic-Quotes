# stoic-pipeline

Offline Python pipeline (runs on the developer PC only) that builds the app's content.

```bash
uv sync
uv run stoic-download            # fetch texts into data/raw/ (gitignored), write data/sources.json
uv run stoic-download --verify   # check raw files against the recorded SHA-256
uv run stoic-split               # data/raw/ -> data/passages/*.jsonl
uv run stoic-curate passages ma-4-   # print passages to curate from
uv run stoic-curate add drafts.jsonl # drafts -> data/curated/quotes_*.jsonl
uv run stoic-curate validate     # every rule, exit 1 on any problem
uv run stoic-curate stats        # counts and random samples
uv run stoic-review              # approve / edit / reject, one entry at a time
uv run stoic-legacy              # trace the old CSV quotes (legacy_report.md)
uv run ruff check && uv run pytest
```

## Sources (public domain only)

| Work | Translator | Year | Source |
|---|---|---|---|
| Meditations | George Long | 1862 | Project Gutenberg #15877 |
| Discourses, Enchiridion | George Long | 1877 | Wikisource |
| Moral Letters to Lucilius | Richard M. Gummere | 1917, 1920, 1925 | Wikisource (Loeb) |

Every file is pinned in `data/sources.json` by URL, Wikisource revision id and SHA-256.

## Rules every quote passes

- Text is an exact substring of its passage (only whitespace is normalized).
- Context, citation, author, translator and year are copied from the passage.
- Unique id (`ma-4-3-a`, `sen-13-4-a`, `epi-ench-1-a`, `epi-1-1-a`), 40 to 400 characters.
- No near duplicates; themes and needs from a fixed vocabulary; no dashes in explanations.

## Curation notes

- Skipped on purpose: lines Marcus or Seneca quote from other writers (Plato, poets,
  Epicurus), passages that could read as encouraging suicide, and passages that ask
  the reader to accept abuse (for example Enchiridion 30).
- Fragments of Epictetus are not used: many are of doubtful authenticity.
- Rejected entries are kept in `data/curated/rejected.jsonl`.
