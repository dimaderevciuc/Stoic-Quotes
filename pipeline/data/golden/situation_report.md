# Situation matching

157 situations, 50 labeled test sentences, 20 off topic sentences. Quotes only (no situations): recall@5 0.370, hit@5 0.880.

- shown: share of test sentences that get a situation
- right: of those shown, share where it is one of the expected situations
- off topic shown: share of off topic sentences that wrongly get a situation
- recall@5 / hit@5: quote metrics with the situation's quotes first

| Threshold | shown | right | off topic shown | recall@5 | hit@5 |
|---|---|---|---|---|---|
| 0.80 | 1.00 | 0.94 | 0.85 | 0.650 | 0.980 |
| 0.81 | 1.00 | 0.94 | 0.70 | 0.650 | 0.980 |
| 0.82 | 1.00 | 0.94 | 0.55 | 0.650 | 0.980 |
| 0.83 | 1.00 | 0.94 | 0.45 | 0.650 | 0.980 |
| 0.84 | 1.00 | 0.94 | 0.20 | 0.650 | 0.980 |
| 0.85 | 1.00 | 0.94 | 0.15 | 0.650 | 0.980 |
| 0.86 | 1.00 | 0.94 | 0.15 | 0.650 | 0.980 |
| 0.87 | 1.00 | 0.94 | 0.05 | 0.650 | 0.980 |
| 0.88 | 1.00 | 0.94 | 0.05 | 0.650 | 0.980 |
| 0.89 | 1.00 | 0.94 | 0.00 | 0.650 | 0.980 |
| 0.90 (chosen) | 0.98 | 0.96 | 0.00 | 0.650 | 0.980 |
| 0.91 | 0.88 | 0.98 | 0.00 | 0.630 | 0.960 |
| 0.92 | 0.72 | 1.00 | 0.00 | 0.602 | 0.960 |
| 0.93 | 0.62 | 1.00 | 0.00 | 0.570 | 0.940 |

## Matches at 0.90

| Sentence | Best situation | Score | Shown | Expected |
|---|---|---|---|---|
| I got rejected after a job interview and I feel like a failure | rejected-after-interview | 0.917 | yes | yes |
| My boss criticized me in front of the whole team today | criticized-by-boss | 0.937 | yes | yes |
| I can't stop worrying about the future | worry-about-future | 0.950 | yes | yes |
| my grandmother died last week and i can't stop crying | death-of-grandparent | 0.918 | yes | yes |
| I feel so lonely, I don't have any friends in this new city | new-city-alone | 0.945 | yes | yes |
| Someone cut me off in traffic and I'm still furious | road-rage | 0.946 | yes | yes |
| my best friend betrayed my trust and part of me wants revenge | friend-betrayed-me | 0.932 | yes | yes |
| I keep procrastinating on my thesis and the deadline is getting closer | procrastination | 0.906 | yes | yes |
| I can't get out of bed in the morning, I have zero motivation | cant-get-up | 0.947 | yes | yes |
| I'm jealous of my friends who all seem more successful than me | jealous-of-friends | 0.934 | yes | yes |
| I'm terrified of giving a presentation tomorrow | presentation-nerves | 0.943 | yes | yes |
| I made a big mistake at work and I keep replaying it in my head | mistake-at-work | 0.945 | yes | yes |
| I care way too much about what other people think of me | fear-of-judgment | 0.911 | yes | yes |
| I lost my job and I'm scared about money | money-worries | 0.909 | yes | yes |
| I was just diagnosed with a chronic illness | new-diagnosis | 0.952 | yes | yes |
| I'm afraid of dying | fear-of-death | 0.966 | yes | yes |
| My girlfriend broke up with me and I miss her | breakup | 0.933 | yes | yes |
| I'm overwhelmed, I have way too many things to do | overwhelmed-workload | 0.921 | yes | yes |
| my coworker is always rude and it drives me crazy | difficult-coworker | 0.939 | yes | yes |
| I feel like I'm wasting my life | wasting-life | 0.945 | yes | yes |
| I want to quit smoking but I keep relapsing | relapsed | 0.904 | yes | yes |
| I waste hours scrolling on my phone every night | phone-addiction | 0.947 | yes | yes |
| people make fun of me since I started going to the gym and eating healthy | mocked-for-changing | 0.926 | yes | yes |
| I'm so stressed about my exams next week | exam-stress | 0.951 | yes | yes |
| I'm just not as talented as everyone else | imposter-feeling | 0.899 | no | no |
| I feel like a failure compared to people my age | behind-in-life | 0.911 | yes | yes |
| I always want more money, I'm never satisfied | never-enough | 0.945 | yes | yes |
| my whole life changed suddenly and I don't know how to cope | sudden-change | 0.917 | yes | yes |
| I'm moving to another country and I feel anxious about it | moving-away | 0.924 | yes | yes |
| I'm burnt out and I just want to escape on a vacation | burnout | 0.919 | yes | yes |
| I can't forgive my father for how he treated me | cant-forgive-parent | 0.938 | yes | yes |
| I'm angry at myself for being so lazy | angry-at-my-laziness | 0.949 | yes | yes |
| someone insulted me online and I can't stop thinking about it | insulted-online | 0.934 | yes | yes |
| I don't know what my purpose in life is | no-purpose | 0.945 | yes | yes |
| I'm way too hard on myself | too-hard-on-myself | 0.931 | yes | yes |
| I get impatient because I'm learning guitar so slowly | slow-progress | 0.909 | yes | yes |
| I feel stuck, nothing in my life ever changes | stuck-in-a-rut | 0.917 | yes | yes |
| The news and politics make me angry and anxious all the time | news-overwhelm | 0.941 | yes | yes |
| my friend lost her mother and I don't know how to support her | comfort-grieving-friend | 0.939 | yes | yes |
| I got promoted and I worry it's going to my head | passed-over | 0.911 | yes | no |
| It hurts when people never thank me for helping them | not-appreciated | 0.928 | yes | yes |
| I get really defensive when someone disagrees with me | defensive-when-criticized | 0.939 | yes | yes |
| I can't fall asleep because my thoughts keep racing | cant-sleep | 0.937 | yes | yes |
| I'm getting older and it scares me | getting-older | 0.958 | yes | yes |
| I live with back pain every single day | chronic-pain | 0.940 | yes | yes |
| Should I take the risk and start my own business? | big-risk | 0.942 | yes | yes |
| It feels like everyone is against me | comparing-myself | 0.903 | yes | no |
| I keep buying things I don't need | impulse-buying | 0.933 | yes | yes |
| I feel guilty because I lied to a friend | lied-guilt | 0.932 | yes | yes |
| nothing ever goes my way, I'm so unlucky | bad-luck | 0.929 | yes | yes |
