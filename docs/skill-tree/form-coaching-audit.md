# Skill Tree Form Coaching Audit

Date: 2026-06-02

## Brutal Coach Verdict

The app is not empty. It has a lot of form content. But it is not yet consistently good enough to teach someone the actual technique.

The strongest layer is `SkillGuideLibrary.swift`: many major skills have real coaching standards, assistance options, tips, and mistake fixes. The weakest layer is the quick `formCues`/`commonMistakes` copy inside `SkillTreeContent.swift`, plus the in-session explainer cue map. That is probably why the app feels generic even though deeper guide content exists.

My coach read: this is a good first content system, not a finished coaching system.

## What I Audited

Primary content surfaces:

- `UNBOUND/Models/SkillTreeContent.swift`
  - 118 skill nodes with short descriptions, `formCues`, and `commonMistakes`.
  - Good for scanning, not always good for learning.
- `UNBOUND/Views/Home/SkillGuideLibrary.swift`
  - Rich guide tabs: standard, assistance, tips, and mistake fixes.
  - This is the best current teaching layer.
- `UNBOUND/Views/Home/Components/FormPhaseSlideshow.swift`
  - Four-step breakdowns with art routing.
  - Strong where custom phase content exists, weak when it falls back to generic family phases.
- `UNBOUND/Models/SkillTrainingPlan.swift`
  - The in-session explainer has exercise descriptions, but the richer cue dictionary is empty.

## Rubric

- A: Actually teaches the skill. Has standard, setup, execution, common failure, fix, regression, and proof standard.
- B: Useful. Correct and specific enough to help, but missing one or two important coaching dimensions.
- C: Technically fine but generic. A beginner can read it and still not know what to do differently.
- D: Too shallow, contradictory, or missing important risk controls.
- F: Missing, unreachable, or unsafe for the movement risk.

## System-Level Grades

| Layer | Grade | Coach Read |
| --- | --- | --- |
| Skill guide tabs | B+ | The best part. Many hard skills are explained with standards, regressions, and fixes. |
| Quick node cues | C | Most nodes have bullets, but many bullets are generic and do not teach diagnostics. |
| Common mistakes | C+ | Usually directionally right, but many say the obvious without explaining the correction. |
| Phase slideshow | B- | Good for custom nodes, but dangerous to rely on generic fallbacks for anchor skills. |
| In-session explainer cues | D | Descriptions exist, but `ExerciseExplainerLibrary.formCues` is empty, so sessions can feel thin. |
| Safety/risk gating in copy | C | Some risky skills are handled well, but release/power/OAH/shoulder-extension work needs more explicit stop criteria. |

## Biggest Concrete Problems

1. The app has coaching depth, but it is hidden in the guide layer.

   The quick skill node copy is what users scan first. Too many nodes say things like "body straight", "control descent", "no swing", "partial ROM" without telling the athlete how to set the position, what to feel, how to regress, or how to know the rep counts.

2. In-session coaching is underbuilt.

   `ExerciseExplainerLibrary.formCues` is currently empty. That means training sessions cannot reliably pull richer exercise-specific cues unless each prescription already carries them. For a coaching app, this is the clearest content architecture gap.

3. Some risky or advanced skills do not get advanced-level coaching.

   One-arm handstand work, 360-degree pulls, clapping handstand push-ups, triple clap push-ups, German hang, and lever rows need more safety, bail, readiness, and failure-standard detail.

4. Some quick cues are misleading or awkward.

   The guide layer may be correct, but the first-facing cue can still hurt trust.

5. The row family still needs clearer distinctions.

   The newer art/content work helped, but the coaching still has to make "tuck row", "straddle row", and "tuck front lever pull-up" impossible to confuse.

## Movement Family Grades

| Family | Grade | Coach Read | Priority |
| --- | --- | --- | --- |
| Pull-ups and chin-ups | B | Guide layer is useful. Quick cues are mostly acceptable. Needs more consistent shoulder/scap sequence and stop criteria for explosive work. | Medium |
| Muscle-ups | A- | One of the best authored areas. Standards, transition, assistance, and common failures are actually useful. | Low |
| Rows and lever rows | C+ | Base guide is decent, but quick cues are too generic and distinctions are still weak. | High |
| Front levers | B+ | Good guide and phase standards. Needs stronger connection between lever holds and lever rows. | Medium |
| Back levers and German hang | B- | Guide content is good, but German hang phase content is not surfaced due to a switch returning `[]`. Risk level makes this higher priority. | High |
| Planche | B+ guide, C+ quick | Guide is strong. Quick full-planche cue has a bad/confusing hip line. | High |
| Push-ups and dips | B | Solid enough, but quick cues need more wrist, elbow, shoulder, and range diagnostics. | Medium |
| Pike/HSPU/vertical press | B- | Guide is useful. Quick pike description is questionable. Release HSPU needs stricter catch/landing rules. | High |
| Handstand | B | Wall and freestanding handstand guide/phases are useful. | Medium |
| One-arm handstand | C- | Not enough for an elite balance skill. Needs weight-shift, pelvis stack, support shoulder elevation, finger pressure, exits, and partial-support drills. | High |
| Core, L-sit, raises | C+ | Mostly correct but often generic. Needs pelvic tilt, compression, scapular depression, and regression specifics. | Medium |
| Legs, pistol, Nordic | B | Generally better than average. Pistol/Nordic content has enough shape. Accessories are thinner. | Medium |
| Power/release skills | C- | Needs landing/catch mechanics, failure-stop criteria, and stricter prerequisites. | High |

## Specific Brutal Findings

### `pp.one-arm-row`

Current quick cues are not enough for the skill:

- "Body straight head-to-heels"
- "Free arm tucked or held out"
- "Pull elbow to ribs, no twist"
- "Squeeze shoulder blade at top"

This is not wrong, but it is shallow. A coach would also expect: handle height, foot width, square pelvis/ribs, shoulder depression before pull, anti-rotation standard, full bottom reach, chest/rib target, free-hand assistance rules, and a clean regression path.

Verdict: C quick copy, B guide copy. Rewrite quick copy.

### `pp.tuck-row`, `pp.straddle-row`, `pp.tuck-front-lever-pullup`

These are not the same skill, but the app must make that obvious:

- Tuck row: low bar/ring lever row, knees tucked, lever shape assisted by body position.
- Straddle row: longer lever, legs open, hips level, body closer to a front-lever row.
- Tuck front lever pull-up: hanging from the bar, body held horizontal in a tuck front lever before the pull.

Current guide content makes the distinction better than the quick node copy. The quick layer should explicitly state the difference because this was already confusing in the product.

Verdict: C+ overall. Rewrite now.

### `pl.full-planche`

The guide is strong and says the right thing: body roughly parallel to the floor. The quick cue says "Hips above shoulder height (piking = failure)", which is confusing and arguably wrong. A full planche standard should be hips level with shoulders/body horizontal, not hips above shoulders.

Verdict: A- guide, D quick cue. Fix immediately.

### `cal.pike-pushup`

The quick description says "back rounded". That can miscue athletes into collapsing through the thoracic spine. The real coaching target is hips high, shoulders open/elevated, ribs controlled, head tracking between hands toward a tripod-like point, elbows controlled, and vertical pressing path.

Verdict: C quick copy. Rewrite.

### `pp.dead-hang`

The quick description says "Passive hang ... shoulders engaged." That reads contradictory. The guide correctly distinguishes passive hanging from the active controlled hang used for skill progress.

Verdict: B guide, C quick copy. Clarify wording.

### `cl.german-hang`

Guide content is good and appropriately cautious. But the phase slideshow switch returns an empty array for German hang, while `backLeverPhases` has a German hang branch that would produce a useful four-phase breakdown. For a shoulder-extension skill, missing phase coaching is not acceptable.

Verdict: B guide, F phase routing. Fix immediately.

### `oah.one-arm-handstand-5s` and `oah.full-one-arm-handstand`

The content needs to be much more technical. One-arm handstand coaching should talk about shoulder elevation, weight shift, hand placement, straddle/pelvis position, support-side stack, finger pressure, free-hand tapering, wall/fingertip assistance, and bailout standards.

Verdict: C- for an elite skill. Rewrite now.

### `cl.three-sixty-pulls`

This should be treated like a high-risk ring power/catch skill, not just a cool advanced pulling node. It needs explicit readiness, shoulder prep, swing control, catch position, exit, and stop criteria.

Verdict: C-/D. Rewrite now.

### `cal.clapping-handstand-pushup` and `cal.triple-clap-pushup`

Release skills need landing/catch mechanics. The app should tell the athlete to stop when height drops, elbows start absorbing badly, the hand catch gets narrow/wide, or the line turns into panic.

Verdict: C-. Rewrite now.

### `ld.pistol-squat`

The guide is solid. Quick copy should still include ankle depth, knee tracking, counterbalance, box/counterweight regressions, and the difference between controlled depth and collapsing into the bottom.

Verdict: B. Good start.

## Node Triage

### Good Enough As A First Teaching Pass

These are not perfect, but they are good enough to ship while higher-risk content is fixed:

- `pp.muscle-up`
- `pp.ring-muscle-up`
- `pp.pullup`
- `pp.strict-pullup`
- `pp.chin-up`
- `pp.strict-chin-up`
- `pp.weighted-pullup`
- `pp.weighted-chin-up`
- `hs.wall-handstand-30`
- `hs.freestanding-hs-30`
- `cl.tuck-front-lever`
- `cl.straddle-front-lever`
- `cl.full-front-lever`
- `cl.skin-the-cat`
- `cl.full-back-lever`
- `pl.tuck-planche`
- `pl.straddle-planche`
- `pl.half-lay-planche`
- `ld.pistol-squat`
- `ld.weighted-pistol`
- `ld.nordic-curl`
- `ld.nordic-hip-hinge`
- `cal.pushup`
- `cal.5-dips`
- `cal.ring-dip`

### Rewrite Now

These are the ones I would not let stay as-is if the goal is a high-quality technical skill tree:

- `pp.one-arm-row`
- `pp.tuck-row`
- `pp.straddle-row`
- `pp.tuck-front-lever-pullup`
- `pp.dead-hang`
- `pl.full-planche`
- `cal.pike-pushup`
- `cal.clapping-handstand-pushup`
- `cal.triple-clap-pushup`
- `cl.german-hang`
- `cl.three-sixty-pulls`
- `oah.one-arm-handstand-5s`
- `oah.full-one-arm-handstand`
- `hs.wall-supported-oah`
- `pp.clapping-pullup`
- `pp.explosive-pullup`
- `pp.oap-negative`
- `pp.one-arm-pullup`
- `pp.heighted-chin-up`
- `pp.one-arm-chin-up`

### Rewrite Second

These are mostly correct but still not deep enough to teach well:

- `pp.incline-row`
- `pp.row`
- `pp.decline-row`
- `pp.wide-pullup`
- `pp.l-sit-chin-up`
- `pp.strict-muscle-up`
- `cal.incline-pushup`
- `cal.decline-pushup`
- `cal.diamond-pushup`
- `cal.sphinx-pushup`
- `cal.archer-pushup`
- `cal.one-arm-pushup`
- `cal.explosive-pushup`
- `cal.floating-pike-pushup`
- `cal.handstand-pushup`
- `cal.ninety-degree-pushup`
- `cal.bent-arm-press`
- `cal.pseudo-planche-pushup`
- `cal.tuck-planche-pushup`
- `pl.bent-arm-planche`
- `cl.hollow-body-30`
- `cl.hanging-knee-raise`
- `cl.hanging-leg-raise`
- `cl.toes-to-bar`
- `cl.knee-raise`
- `cl.leg-raise`
- `cl.knee-ab-rollout`
- `cl.standing-ab-rollout`
- `cl.dragon-flag`
- `cl.dragon-flag-hip-raise`
- `cl.v-sit`
- `cl.straddle-l-sit`
- `cl.vertical-l-sit`
- `hs.headstand`
- `hs.tuck-handstand`
- `hs.tuck-press`
- `hs.straddle-press`
- `hs.press-to-handstand`
- `hs.crow-pose`
- `hs.crane-pose`
- `hs.flying-crow`
- `hs.elbow-lever`
- `hs.one-arm-elbow-lever`

### Acceptable But Thin

These can stay lighter because they are basics, accessories, or less technical nodes, but they should not pretend to be full coaching lessons:

- `ld.goblet-20`
- `ld.split-squat`
- `ld.bulgarian-split-squat`
- `ld.weighted-split-squat`
- `ld.weighted-bss`
- `ld.step-up`
- `ld.deep-squat`
- `ld.glute-bridge`
- `ld.calf-raise`
- `ld.weighted-sl-calf`
- `ld.shrimp-squat`
- `ld.sissy-squat`
- `ld.leg-extensions`
- `ld.box-jump`
- `ld.jumping-squat`
- `ld.fire-hydrant`
- `ld.single-leg-glute-bridge`
- `ld.flying-kickback`
- `ld.advancing-nordic-curl`
- `ld.floor-to-ceiling-squat`
- `cal.plank-30`
- `cal.l-sit-10`
- `cal.bench-dip`
- `cl.crunch`
- `cl.reverse-crunch`
- `cl.superman-plank`
- `cl.extended-plank`
- `cl.levitation-crunch`
- `cl.inverted-situp`
- `cl.decline-situp`
- `cl.bird-dog-plank`
- `cl.semi-straddle-l-sit`
- `hs.wall-plank`

## What A Better Coaching Node Should Contain

Every technical node should answer these questions:

1. Setup: What exactly do hands, grip, shoulders, pelvis, legs, and implement height do before the rep starts?
2. Execution: What path does the body take?
3. Proof standard: What counts, what does not count, and where is the rep or hold measured?
4. Most common failure: What does the athlete usually do wrong?
5. Fix: What regression or cue corrects that failure?
6. Assistance: How can a beginner train the pattern without faking the standard?
7. Stop criteria: What pain, loss of shape, or control failure ends the set?

The current content often has 2, 3, and 4. The better guide pages sometimes have all seven. The quick nodes and in-session explainer usually do not.

## Recommended Implementation Plan

1. Do not change the ladder system for this.

   This is not a graph problem. This is a coaching content depth problem.

2. Make `SkillGuideLibrary` the source of truth for teaching.

   Quick node cues can stay short, but they should be distilled from the deeper guide content instead of feeling like separate generic bullets.

3. Populate `ExerciseExplainerLibrary.formCues`.

   This is the fastest way to make the actual training session feel less generic. The session should show specific cues for "Tuck Front Lever Pull-Up", "One-Arm Row", "Pike Push-Up", "German Hang", etc.

4. Fix the dangerous or trust-breaking items first.

   Immediate fixes:

   - German hang phase routing.
   - Full planche quick hip cue.
   - Pike push-up quick description.
   - Dead hang passive/active wording.
   - One-arm handstand technical detail.
   - 360-degree pulls safety and catch standard.
   - Release skill landing/catch standards.
   - Row-family distinctions.

5. Add content coverage tests.

   For high-risk nodes, require:

   - Non-empty guide.
   - Non-empty phase slideshow.
   - No generic default phase fallback.
   - Assistance/regression text.
   - Stop criteria or safety text.

6. Then do the broad rewrite pass.

   After the high-risk fixes, rewrite all row, core, vertical press, and accessory nodes so the app feels like a coach, not a glossary.

## Bottom Line

This is a pretty good start structurally. It is not a pretty good finish pedagogically.

The app currently has enough content to look filled out, and enough strong guide pages to prove the direction works. But if the goal is "someone can learn the techniques from this," the weak quick-cue layer and empty in-session cue layer are holding it back hard. The next pass should not add more nodes. It should make the existing nodes coach-level.
