# stoic-pipeline

Offline Python pipeline (runs on the developer PC only) that builds the app's content.

```bash
uv sync
uv run stoic-download            # fetch texts into data/raw/ (gitignored), write data/sources.json
uv run stoic-download --only allen-thinketh   # refresh one source, keep the rest
uv run stoic-download --verify   # check raw files against the recorded SHA-256
uv run stoic-split               # data/raw/ -> data/passages/*.jsonl
uv run stoic-curate passages ma-4-   # print passages to curate from
uv run stoic-curate add drafts.jsonl # drafts -> data/curated/quotes_*.jsonl
uv run stoic-curate validate     # every rule, exit 1 on any problem
uv run stoic-curate stats        # counts and random samples
uv run stoic-review              # approve / edit / reject, one entry at a time
uv run stoic-legacy              # trace the old CSV quotes (legacy_report.md)
uv run stoic-embed eval          # compare models on golden/eval_situations.jsonl (eval_report.md)
uv run stoic-embed export        # model + quote vectors -> ../assets/embedding/ (int8)
uv run stoic-embed parity        # golden/parity.json, checked by the Dart tests
uv run stoic-embed fetch         # download the pinned model into ../assets (not in git)
uv run stoic-situations validate # situation library: schema, quote links, taxonomy
uv run stoic-situations tune     # threshold sweep -> golden/situation_report.md
uv run ruff check && uv run pytest
```

## Sources (public domain only)

| Work | Translator | Year | Source |
|---|---|---|---|
| Meditations | George Long | 1862 | Project Gutenberg #15877 |
| Discourses, Enchiridion | George Long | 1877 | Wikisource |
| Moral Letters to Lucilius | Richard M. Gummere | 1917, 1920, 1925 | Wikisource (Loeb) |
| Of Anger, Consolations to Marcia, Helvia, Polybius (Seneca) | Aubrey Stewart | 1889 | Project Gutenberg #64576 |
| As a Man Thinketh (James Allen) | written in English | 1903 | Project Gutenberg #4507 |

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
- As a Man Thinketh: not Stoic, added on request. Passages claiming that illness,
  poverty or oppression are caused by the sufferer's own thoughts (chapters 2, 3, 5)
  are not used, nor the verses and long passages Allen quotes from others.
- Seneca, Dialogues (Stewart): only Of Anger and the three Consolations. Skipped: passages
  praising death as a release (Marcia 19 to 23, Of Anger 3.15), lines about enduring
  abuse, dated remarks about women, and the flattery of Claudius in To Polybius.
- Approval: the 45 Stewart quotes (`quotes_seneca_dialogues.jsonl`, added 2026-11-12) were
  marked reviewed by Claude at Dima's request, not read by a person. Dima will flag any to
  drop while using the app.
- Rejected entries are kept in `data/curated/rejected.jsonl`.

## Embeddings (Phase 2)

- Model: `thenlper/gte-small` as the int8 ONNX file from `Xenova/gte-small` (MIT),
  pinned by revision and SHA-256. The app runs the same file with ONNX Runtime
  (flutter_onnxruntime) and tokenizes in Dart. Model2Vec static embeddings were
  tried first and replaced: recall@5 0.27 against 0.40 (see `data/golden/eval_report.md`).
- A quote is embedded as the weighted mean of its explanation (2), quote text (1) and
  theme/need words (1). The plain explanation matches how people describe problems.
- Sentences are encoded one at a time, never padded into a batch: the int8 model
  quantizes activations per call, so padding would change the numbers.
- The model file is not in git: after cloning run `uv run stoic-embed fetch`.
- After any change to the curated quotes: `export`, then `parity`, then in the repo
  root `flutter test` and `flutter test integration_test -d linux`.

## Situations (Phase 3)

- `data/situations/taxonomy.jsonl`: 151 situations in 17 categories, approved by Dima.
- `data/situations/situations.jsonl`: per situation 7 example phrases, 3 to 4 hand-picked
  quotes with "how it applies", and a 2 to 4 step exercise. Written and marked reviewed
  by Claude at Dima's request (2026-11-12); Dima will flag changes while using the app.
- Loss (people, pets, pregnancy) and health situations use only gentle, hopeful quotes.
  Abuse situations start the exercise with 112 / 142 / findahelpline.com.
- Match threshold 0.90 (`stoic-situations tune`). Export writes `situations.bin` and
  `situations.json` next to the model.
