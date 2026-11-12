# Retrieval eval

50 situations, 533 quotes. recall@5 counts the expected quotes found in the top 5 (out of at most 5); hit@5 is the share of situations with at least one; int8 is the same model after the app's quantization.

| Model | Size (int8) | Quote text | recall@5 | hit@5 | MRR |
|---|---|---|---|---|---|
| minishlab/potion-base-8M | 7.7 MB | text | 0.128 | 0.460 | 0.305 |
| minishlab/potion-base-8M | 7.7 MB | explanation | 0.217 | 0.600 | 0.489 |
| minishlab/potion-base-8M | 7.7 MB | average | 0.213 | 0.640 | 0.443 |
| minishlab/potion-base-8M | 7.7 MB | weighted | 0.274 | 0.640 | 0.512 |
| minishlab/potion-base-8M, int8 as in the app | | weighted | 0.278 | 0.640 | 0.512 |
| minishlab/blink-8M | 7.8 MB | text | 0.090 | 0.360 | 0.186 |
| minishlab/blink-8M | 7.8 MB | explanation | 0.178 | 0.540 | 0.437 |
| minishlab/blink-8M | 7.8 MB | average | 0.173 | 0.580 | 0.462 |
| minishlab/blink-8M | 7.8 MB | weighted | 0.246 | 0.700 | 0.542 |
| minishlab/blink-8M, int8 as in the app | | weighted | 0.246 | 0.700 | 0.552 |
| minishlab/potion-base-32M | 32.6 MB | text | 0.133 | 0.500 | 0.322 |
| minishlab/potion-base-32M | 32.6 MB | explanation | 0.246 | 0.640 | 0.444 |
| minishlab/potion-base-32M | 32.6 MB | average | 0.238 | 0.660 | 0.500 |
| minishlab/potion-base-32M | 32.6 MB | weighted | 0.290 | 0.660 | 0.522 |
| minishlab/potion-base-32M, int8 as in the app | | weighted | 0.286 | 0.660 | 0.520 |
| minishlab/potion-retrieval-32M | 32.6 MB | text | 0.057 | 0.200 | 0.163 |
| minishlab/potion-retrieval-32M | 32.6 MB | explanation | 0.142 | 0.480 | 0.336 |
| minishlab/potion-retrieval-32M | 32.6 MB | average | 0.126 | 0.400 | 0.298 |
| minishlab/potion-retrieval-32M | 32.6 MB | weighted | 0.190 | 0.600 | 0.445 |
| minishlab/potion-retrieval-32M, int8 as in the app | | weighted | 0.190 | 0.600 | 0.445 |
