# Legacy quotes: decisions

The original `lib/assets/quotes_list.csv` has 64 quotes and no sources. Each was
compared with the public domain passages (`uv run stoic-legacy` writes the full
machine report to `legacy_report.md`). None of the old wording is kept unless it
matches Long or Gummere exactly; where the idea is real, the public domain
translation of the same passage is already in the curated corpus.

## 1. Same wording found, now in the corpus (8)

| Old quote (short) | Corpus id |
|---|---|
| We suffer more often in imagination than in reality | sen-13-4-a |
| If it is not right, do not do it; if it is not true, do not say it | ma-12-17-a |
| Begin at once to live, and count each separate day as a separate life | sen-101-10-a |
| Do not act as if you were going to live ten thousand years | ma-4-17-a |
| Nothing happens to any man that he is not formed by nature to bear | ma-5-18-a |
| It is not the man who has too little, but the man who craves more, that is poor | sen-2-6-a |
| Let us prepare our minds as if we'd come to the very end of life | sen-101-7-a (Gummere wording) |
| If you are pained by external things, it is not they that disturb you | ma-8-47-a |

## 2. Real idea, modern translation: replaced by the public domain wording (14)

| Old quote (short) | Public domain equivalent |
|---|---|
| The soul becomes dyed with the color of its thoughts | ma-5-16-a |
| The best revenge is to be unlike him who performed the injury | ma-6-6-a |
| If you seek tranquility, do less | ma-4-24-a |
| Don't explain your philosophy. Embody it. | epi-ench-46-a |
| People are not disturbed by things, but by the views they take of them | epi-ench-5-a |
| It is not events that disturb people, it is their judgements | epi-ench-5-a |
| Don't seek for everything to happen as you wish | epi-ench-8-a |
| How long are you going to wait before you demand the best for yourself? | epi-ench-50-b |
| To love only what happens, what was destined | ma-7-57-a |
| Whenever you are about to find fault with someone, ask yourself | ma-10-30-a |
| Do every act of your life as though it were the last | ma-2-5-a |
| Accept the things to which fate binds you, and love the people | ma-6-39-a |
| As is a tale, so is life: not how long it is, but how good | sen-77-20-a |
| The happiness of your life depends upon the quality of your thoughts | ma-5-16-a (same passage) |

## 3. Known misattributions: drop (7)

| Old quote | Real origin |
|---|---|
| What we do now echoes in eternity (Marcus) | Line from the film *Gladiator* (2000) |
| Death smiles at us all, but all a man can do is smile back (Marcus) | Film *Gladiator* (2000) |
| The robbed that smiles, steals something from the thief (Seneca) | Shakespeare, *Othello* 1.3 |
| The obstacle is the way (Marcus) | Book title by Ryan Holiday, a paraphrase of ma-5-20 (ma-5-20-a is in the corpus) |
| An angry man opens his mouth and shuts his eyes (Marcus) | Usually attributed to Cato the Elder, not in the Meditations |
| Wealth is not about having a lot of money; it is about having a lot of options (Epictetus) | Modern saying, not in Epictetus |
| Luck is what happens when preparation meets opportunity (Seneca) | Modern saying, not in the Letters |

## 4. Not Stoic authors in scope: drop or keep outside the corpus (4)

Heraclitus (2), Lao Tzu (1), Plutarch (1). The schema only allows Marcus Aurelius,
Seneca and Epictetus.

## 5. Not traced: Dima to decide (31)

The remaining quotes could not be matched to a passage. Most look like modern
translations (Hays, Robin Campbell) or popular paraphrases, for example
"You have power over your mind, not outside events" (Hays), "A gem cannot be
polished without friction" (often attributed to Seneca, no source found) and
"Throw me to the wolves and I will return leading the pack" (no source found).
They are left out of the corpus. Full list with closest passages: `legacy_report.md`.
