# Retrieval eval

50 situations, 533 quotes. recall@5 counts the expected quotes found in the top 5 (out of at most 5); hit@5 is the share of situations with at least one. Every row uses the int8 ONNX file the app ships; the "as in the app" row also quantizes the quote vectors to int8.

| Model | ONNX size | Quote text | recall@5 | hit@5 | MRR |
|---|---|---|---|---|---|
| Xenova/gte-small | 34.0 MB | text | 0.148 | 0.560 | 0.417 |
| Xenova/gte-small | 34.0 MB | explanation | 0.362 | 0.800 | 0.726 |
| Xenova/gte-small | 34.0 MB | weighted | 0.398 | 0.900 | 0.747 |
| Xenova/gte-small, as in the app | | weighted | 0.398 | 0.900 | 0.784 |
| Xenova/all-MiniLM-L6-v2 | 23.0 MB | text | 0.172 | 0.520 | 0.329 |
| Xenova/all-MiniLM-L6-v2 | 23.0 MB | explanation | 0.379 | 0.860 | 0.700 |
| Xenova/all-MiniLM-L6-v2 | 23.0 MB | weighted | 0.407 | 0.900 | 0.748 |
| Xenova/all-MiniLM-L6-v2, as in the app | | weighted | 0.407 | 0.900 | 0.750 |
| Xenova/all-MiniLM-L12-v2 | 34.0 MB | text | 0.197 | 0.660 | 0.391 |
| Xenova/all-MiniLM-L12-v2 | 34.0 MB | explanation | 0.387 | 0.860 | 0.716 |
| Xenova/all-MiniLM-L12-v2 | 34.0 MB | weighted | 0.423 | 0.900 | 0.730 |
| Xenova/all-MiniLM-L12-v2, as in the app | | weighted | 0.423 | 0.900 | 0.729 |

## Earlier: Model2Vec static embeddings (replaced)

| Model | Size (int8) | recall@5 | hit@5 | MRR |
|---|---|---|---|---|
| minishlab/potion-base-8M | 7.7 MB | 0.274 | 0.640 | 0.512 |
| minishlab/blink-8M | 7.8 MB | 0.246 | 0.700 | 0.542 |
| minishlab/potion-base-32M | 32.6 MB | 0.290 | 0.660 | 0.522 |
| minishlab/potion-retrieval-32M | 32.6 MB | 0.190 | 0.600 | 0.445 |
