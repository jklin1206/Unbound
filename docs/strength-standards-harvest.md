# Strength Standards Harvest — strengthlevel.com

Real-world calisthenics performance standards harvested from
[strengthlevel.com](https://strengthlevel.com/strength-standards/), captured
**2026-05-30**. Purpose: ground the UNBOUND skill-rank thresholds in
crowd-sourced data rather than guesses.

**Reference anchor:** adult **male @ ~180 lb bodyweight**. All rep numbers are
single-set max reps unless the unit column says otherwise. `< 1` means the
standard falls below one full rep (i.e. the movement itself is the achievement
at that level — e.g. a Beginner "can't yet do one").

strengthlevel uses a 5-band scale that maps to population percentiles:
Beginner ≈ 5th pct, Novice ≈ 20th, Intermediate ≈ 50th (the "average lifter"),
Advanced ≈ 80th, Elite ≈ 95th.

---

## 1. Primary table — all movements @ 180 lb male

| Movement | slug | unit | Beginner | Novice | Intermediate | Advanced | Elite |
|---|---|---|---|---|---|---|---|
| **Pull family** | | | | | | | |
| Pull-ups | `pull-ups` | reps | < 1 | 6 | 13 | 23 | 32 |
| Chin-ups | `chin-ups` | reps | < 1 | 7 | 13 | 22 | 30 |
| Neutral-grip pull-ups | `neutral-grip-pull-ups` | reps | < 1 | 7 | 15 | 25 | 36 |
| Muscle-ups | `muscle-ups` | reps | < 1 | 2 | 7 | 11 | 17 |
| Inverted row / australian pull-up | `inverted-row` | reps | < 1 | 7 | 19 | 33 | 48 |
| **Push family** | | | | | | | |
| Push-ups | `push-ups` | reps | 5 | 20 | 40 | 64 | 90 |
| Diamond push-ups | `diamond-push-ups` | reps | < 1 | 10 | 24 | 39 | 56 |
| Archer push-ups | `archer-push-ups` | reps | < 1 | 9 | 24 | 44 | 65 |
| One-arm push-ups | `one-arm-push-ups` | reps | < 1 | < 1 | 11 | 26 | 43 |
| Handstand push-ups | `handstand-push-ups` | reps | < 1 | < 1 | 12 | 28 | 46 |
| Dips | `dips` | reps | 1 | 10 | 20 | 31 | 44 |
| Bench dips | `bench-dips` | reps | < 1 | 12 | 32 | 56 | 83 |
| **Legs** | | | | | | | |
| Bodyweight squat | `bodyweight-squat` | reps | < 1 | 17 | 56 | 107 | 167 |
| Pistol squat | `pistol-squat` | reps | < 1 | 3 | 13 | 25 | 38 |
| Lunge | `lunge` | reps | < 1 | 11 | 37 | 69 | 105 |
| Squat jump (jump squat) | `squat-jump` | reps | < 1 | 8 | 34 | 68 | 108 |
| Nordic hamstring curl | `nordic-hamstring-curl` | reps | < 1 | < 1 | 11 | 24 | 39 |
| **Core** | | | | | | | |
| Sit-ups | `sit-ups` | reps | < 1 | 23 | 57 | 99 | 146 |
| Crunches | `crunches` | reps | < 1 | 21 | 54 | 95 | 142 |
| Hanging leg raise | `hanging-leg-raise` | reps | < 1 | 7 | 18 | 31 | 46 |
| Hanging knee raise | `hanging-knee-raise` | reps | < 1 | 6 | 19 | 35 | 52 |
| Lying leg raise | `lying-leg-raise` | reps | < 1 | 7 | 33 | 67 | 107 |

URL pattern: `https://strengthlevel.com/strength-standards/<slug>/lb`

Slug notes:
- `australian-pull-ups` and `inverted-row` are the same page (australian
  redirects to inverted-row).
- `jump-squat` / `squat-jumps` redirect to `squat-jump`.
- `nordic-curl` redirects to the index; the live page is
  `nordic-hamstring-curl`.
- `leg-raises` / `leg-raise` redirect to `lying-leg-raise`; `ab-crunch`
  redirects to `crunches`.

---

## 2. Bodyweight scaling (rep movements)

Lighter lifter = more reps for the same percentile band (less mass to move).
Intermediate (50th pct) and Elite (95th pct) reps at 130 / 180 / 230 lb:

| Movement | Int @130 | Int @180 | Int @230 | Elite @130 | Elite @180 | Elite @230 |
|---|---|---|---|---|---|---|
| Pull-ups | 15 | 13 | 11 | 38 | 32 | 27 |
| Chin-ups | 15 | 13 | 11 | 35 | 30 | 26 |
| Neutral-grip pull-ups | 16 | 15 | 13 | 41 | 36 | 31 |
| Muscle-ups | 6 | 7 | 7 | 18 | 17 | 15 |
| Inverted row | 18 | 19 | 17 | 53 | 48 | 43 |
| Push-ups | 42 | 40 | 37 | 103 | 90 | 79 |
| Diamond push-ups | 23 | 24 | 23 | 61 | 56 | 51 |
| One-arm push-ups | 9 | 11 | 11 | 46 | 43 | 39 |
| Dips | 20 | 20 | 18 | 49 | 44 | 39 |
| Bodyweight squat | 61 | 56 | 51 | 198 | 167 | 144 |
| Sit-ups | 66 | 57 | 50 | 178 | 146 | 124 |
| Crunches | 57 | 54 | 50 | 165 | 142 | 125 |

The scaling is mild but real (~15-25% swing across the 130→230 lb range for
upper-body pulls/pushes; squats and core scale a bit harder because the lighter
lifter moves proportionally less mass). For pull-ups, going from 180→130 lb is
worth roughly +2 reps at Intermediate and +6 at Elite. Note muscle-ups and
one-arm push-ups slightly *invert* at the low end (130 lb Int ≤ 180 lb Int) —
likely thin-sample noise at those bodyweights for hard skills (see §4).

---

## 3. NOT FOUND on strengthlevel.com

These requested (or plausible) movements 302-redirect to the standards index,
meaning the site has **no standards page** for them:

- **Weighted pull-ups** (`weighted-pull-ups`) — no dedicated added-load page.
- **Weighted chin-ups** (`weighted-chin-ups`) — none.
- **Weighted dips** (`weighted-dips`) — none.
  - → The site has **no weighted-bodyweight (added-lb) calisthenics pages at
    all.** Every calisthenics movement on strengthlevel is scored in reps, not
    in added 1RM load. The weighted-progression dimension is not available here.
- **Wide-grip pull-ups** (`wide-grip-pull-ups`) — none (only standard,
  chin, and neutral grip exist).
- **Pike push-ups** (`pike-push-ups`) — none.
- **Plank** (`plank`) — none (no time-based holds at all).
- **L-sit** (`l-sit`, `l-sit-hold`) — none.
- **Front lever** (`front-lever`) — none.
- **Planche** (`planche`) — none.
- **Wall handstand / handstand hold** (`wall-handstand`) — none (only the
  dynamic `handstand-push-ups` exists).
- **Decline push-ups / close-grip push-ups** — none (archer & diamond exist).

Implication for the skill tree: strengthlevel can ground **rep-based**
thresholds well, but the **static-hold isometrics** (plank, L-sit, front
lever, planche, handstand hold) and the **weighted-loading progressions** have
no data here and will need another source or internally-defined standards.

---

## 4. Data-quality note

Sample depth is strong for the core movements and thinner for the skill
movements. Lift counts behind each: push-ups 2.9M, dips 2.15M, pull-ups 4.81M,
chin-ups 1.22M, sit-ups 645K, crunches 659K, bodyweight squat 546K, one-arm
push-ups 450K, neutral-grip pull-ups 350K, diamond push-ups 343K, hanging leg
raise 308K, pistol squat 310K, lunge 193K, lying leg raise 164K, bench dips
162K, squat jump 150K, inverted row 101K, hanging knee raise 87K, archer
push-ups 76K, nordic hamstring curl 68K, muscle-ups 613K (high count but
self-reported and easy to over-log). Two things look off and warrant caution:
(a) the harder skill movements (muscle-ups, one-arm push-ups, nordic curls)
show non-monotonic bodyweight scaling at the 130 lb tail — Intermediate at
130 lb sometimes dips *below* 180 lb, which is sample noise, not real physiology;
(b) self-reported rep counts skew optimistic for ego-friendly lifts (push-ups,
sit-ups, muscle-ups) and for unloaded movements with no objective ceiling, so
treat the Elite reps as "strong gym human," not "world record." Overall the
180 lb-male anchor rows are trustworthy for the high-count lifts and directionally
fine for the rest.
