# Evidence-Backed Branch Form Audit

Date: 2026-06-02

## Purpose

This audit uses branch-specific review agents plus external calisthenics, gymnastics, biomechanics, and sports-medicine sources to answer one question:

Are the current form cues enough for someone who wants to actually learn the techniques?

Short answer: not consistently.

The app has strong guide and slideshow content in several places, but the first-touch node cards and in-session training cues lag behind. A motivated user can learn some skills if they open the guide tabs, but the app is not yet consistently coach-level from the normal flow.

## Overall Verdict

| Surface | Rating | Read |
| --- | --- | --- |
| `SkillGuideLibrary` | B+ | Often genuinely useful; this is the strongest teaching layer. |
| `FormPhaseSlideshow` | B | Strong where custom phases exist; weak where routing or identity is wrong. |
| `SkillTreeContent` quick cues | C+ | Usually directionally correct, but often too generic or shorthand for technical skills. |
| `SkillTrainingPlanLibrary` | C+ | Good exercise selection in places, but some plans conflict with node standards. |
| `ExerciseExplainerLibrary.formCues` | D | The map is empty, so in-session cue depth is not reliable. |

The core product problem is not lack of content volume. It is uneven coaching precision across surfaces.

## Branch Grades

| Branch | Branch Grade | Form Cue Adequacy | Main Read |
| --- | --- | --- | --- |
| Pulling power | B+ | B full app, C+ node cards | Strong guide/slides; fix muscle-up standard mixing, one-arm tendon risk, release skill safety, row wording. |
| Push/dips/HSPU | B+ | 7.6/10 | Strong guide/slides; fix HSPU head path, bench dip routing, tuck planche push-up plan, release skill volume. |
| Levers/rings | B- | B- overall, D for `cl.three-sixty-pulls` | Mostly safety-aware; 360 pulls are currently teaching the wrong skill identity. |
| Core/compression/L-sit | B+ | A- guide/slides, lower in node/plan | No P0 safety problem; fix metadata/progression and first-touch cue precision. |
| Legs/pistols/Nordics | B+ | 7.5/10 | Strong enough overall; fix plyo/Nordic volume, leg extension identity, floor-to-ceiling mismatch. |
| Handstand/OAH | C+ | 6.5/10 | Handstand basics are okay; OAH is under-milestoned and under-coached. |
| Planche/arm balances | B+ | B | Coherent path; fix full planche hip cue and tuck planche push-up gating. |

## Highest Priority Fixes

### P0: Correct Wrong Or Risky Skill Identity

1. Rewrite `cl.three-sixty-pulls`.

   Current app content appears to describe a release/re-catch skill. The reviewed calisthenics/ring sources define 360 pulls as a controlled ring arc through active hang, front-lever lane, inverted hang, back-lever lane, German hang, and back. This should not be taught as a bar release move.

2. Fix German hang slideshow routing.

   `FormPhaseSlideshow` returns an empty array for `cl.german-hang`, even though the German hang phases exist in `backLeverPhases`. For a loaded shoulder-extension skill, this is a real coaching gap.

3. Replace HSPU "forehead" language.

   HSPU and clapping HSPU should cue a crown/head-pad tripod path, not forehead contact. Forehead language risks teaching a neck-forward bottom.

4. Fix one-arm handstand and wall-supported OAH coaching.

   OAH needs prerequisites, side-bend/flag progression, fingertip/tent support progression, support-shoulder stack, and exit rules. Wall-supported OAH should not cue a back-against-wall lean that encourages banana shape.

5. Fix `cal.tuck-planche-pushup` gating and plan.

   The movement requires a real tuck planche, but the graph currently gates it from pseudo-planche push-up only. The plan should include tuck planche holds, band-assisted tuck reps, tuck negatives, and a feet-never-touch standard.

### P1: Fix Contradictions And Thin High-Risk Cues

- Separate regular bar muscle-up, ring muscle-up, and strict muscle-up standards.
- Add low-volume and pain-stop rules for one-arm pull-up/chin-up negatives.
- Add release-skill standards for clapping pull-ups, clapping push-ups, triple clap push-ups, and clapping HSPU.
- Fix full planche cue from "hips above shoulder height" to "hips level with shoulders / body roughly parallel."
- Fix `hs.wall-plank` wording: shoulder elevation is needed; the failure is shoulder collapse, not "shrugged shoulders."
- Split `cal.bench-dip` away from the bar-dip plan.
- Fix `ld.leg-extensions` identity: open-chain leg extension versus reverse-Nordic/bodyweight knee extension.
- Fix floor-to-ceiling squat slideshow to match the supine no-hands node standard.
- Reduce plyometric and Nordic tier targets that encourage fatigue rep-outs.
- Clarify `cl.vertical-l-sit` with a measurable visual standard.
- Replace `L-Sit Max Hold` "push to break in form" with stop-at-first-break / accumulate clean seconds.

### P2: Raise First-Touch Cue Quality

- Promote guide/slideshow cues into `SkillTreeContent` for rows, rollouts, raises, dragon flag, German hang, back lever, OAH, and planche.
- Populate `ExerciseExplainerLibrary.formCues` for common drills and high-risk progressions.
- Add coverage tests for high-risk nodes requiring guide, phase content, assistance/regression, and stop criteria.

## Branch Details

### Pulling Power

Grade: B+

Adequacy: B across the full app; C+ from node cards alone.

What is good:

- Pull-up, row, and muscle-up guide/slideshow content is generally strong.
- Basic pull-up and row standards are serviceable.
- One-arm and release skills are recognized as advanced.

What is not enough:

- `pp.muscle-up` mixes regular bar muscle-up and strict/false-grip expectations.
- One-arm pull-up/chin-up path needs measurable assistance and tendon pain rules.
- Release pull-ups need low-volume power standards and catch mechanics.
- Rows need "straight-arm active bottom" language, not dead-hang language.
- `ExerciseExplainerLibrary.formCues` is empty, so session drills are thinner than detail pages.

Evidence-backed cue additions:

- Dead hang: reach long, keep neck long, shoulders controlled, step down before grip peels open.
- Pull-up/chin-up: scapula first, then elbows; chest rises; full extension without dumping into loose shoulders.
- Wide pull-up: wider only counts if range and shoulder comfort stay intact.
- Lever rows: set the lever before rowing; hips level with shoulders; posterior pelvic tilt/hollow; same lever on the eccentric.
- One-arm path: use measurable towel, band, or pulley assistance; negatives only when every inch is controlled; stop on rising tendon pain.
- Bar muscle-up: high wrist helps but is not mandatory; pull to low ribs/stomach, keep bar close, chest over hands before pressing.

Key sources:

- [GMB Pull-Up Progression](https://gmb.io/pull-ups/)
- [GMB Hanging / Active Hang](https://gmb.io/hanging/)
- [Dickie et al., Pull-Up Variation EMG](https://winchester.elsevierpure.com/en/publications/electromyographic-analysis-of-muscle-activation-during-pull-up-va-3/)
- [Prinold and Bull, Scapula Kinematics / Impingement Risk](https://pubmed.ncbi.nlm.nih.gov/26383875/)
- [High-Level Gymnast Shoulder Injuries](https://pmc.ncbi.nlm.nih.gov/articles/PMC8493315/)
- [CrossFit Journal: The Muscle-Up PDF](https://library.crossfit.com/free/pdf/Muscle-upNov02.pdf)
- [StrengthLog Ring Muscle-Up Guide](https://www.strengthlog.com/ring-muscle-up/)
- [Tuck Front Lever Row Guide](https://calisthenics.com/exercise/tuck-front-lever-row/)
- [Front Lever Technique Guide](https://calisthenicsworld.org/front-lever/)

### Push, Dips, HSPU, Release Skills

Grade: B+

Adequacy: 7.6/10 overall. Guide 8.8/10, slideshow 8.5/10, node cards 6.8/10, training plans 6.2/10.

What is good:

- Push-up, dip, pike/HSPU, planche-press, and release-skill guides are mostly useful.
- The guide layer already has good safety language around dips, release work, and tripod paths.

What is not enough:

- HSPU node copy uses forehead contact language.
- `cal.bench-dip` routes into the same plan as bar dip.
- `cal.tuck-planche-pushup` plan is too pseudo-planche focused.
- Triple clap and release skills should be singles or tiny fresh sets, not volume progression.
- Wall versus freestanding clapping HSPU should be explicit as drill versus scoring standard.

Evidence-backed cue additions:

- Push-ups: finish with active shoulder blades and elbow lockout; regress before hips sag or head leads.
- Dips: start from a still support; shoulders depressed; stop at the deepest pain-free bottom before shoulders roll forward.
- Bench dips: keep hips close to bench; do not chase depth behind the body; stop on anterior shoulder pinch.
- Pike/HSPU: hands and head form a tripod; head target slightly forward of hands; push tall at lockout with ribs down.
- Explosive/release skills: clear airtime first; hands return before landing; catch with soft elbows and active shoulders.

Key sources:

- [NSCA: Plyometric Exercises](https://www.nsca.com/education/articles/kinetic-select/plyometric-exercises/)
- [NASM: Plyometric Push-Up](https://www.nasm.org/resource-center/exercise-library/plyometric-push-up)
- [CrossFit Gymnastics Course Seminar Guide PDF](https://assets.crossfit.com/pdfs/seminars/SMERefs/Gymnastics/GymnasticsCourse_SeminarGuide.pdf)
- [GymnasticBodies: Planche Lean](https://www.gymnasticbodies.com/exercises/planche-lean/)
- [GymnasticBodies: Parallel Bar Dip](https://www.gymnasticbodies.com/exercises/parallel-bar-dip/)
- [GymnasticBodies: Hollow Back Press](https://www.gymnasticbodies.com/exercises/hollow-back-press/)
- [Push-Up Plus EMG Meta-Analysis](https://pmc.ncbi.nlm.nih.gov/articles/PMC6863690/)
- [Anterior Shoulder Instability Rehab Protocol](https://www.drlintner.com/contents/rehab-protocols/anterior-shoulder-dislocationsubluxation-conservative-rehab)

### Levers, Rings, Shoulder Extension

Grade: B-

Adequacy: B- overall; front lever B+, back lever B, German hang/skin-the-cat B+, 360 pulls D.

What is good:

- Front lever, back lever, German hang, and skin-the-cat guide content is mostly safety-aware.
- The app already understands pain-free shoulder extension and controlled exits in several places.

What is not enough:

- `cl.three-sixty-pulls` is the wrong skill identity.
- German hang phase content exists but is not surfaced.
- German hang and skin-the-cat training plans should be split: hold focus versus controlled rep focus.
- Back lever should be more explicit about slight protraction/depression, straight elbows, and grip stress.

Evidence-backed cue additions:

- 360 pulls: controlled ring arc, not release; active hang -> front-lever lane -> inverted hang -> back-lever lane -> German hang -> reverse.
- German hang: use low rings or toe assistance; depth only counts if you can reverse it; stop on sharp anterior shoulder pain.
- Skin-the-cat: start from a quiet active hang, tuck tight, rotate slowly, and reverse without dropping.
- Back lever: lower to horizontal, do not fall into it; slight protraction/depression; pronated or neutral ring grip before supinated grip.

Key sources:

- [Calisteniapp Front Lever](https://calisteniapp.com/articles/front-lever-calisthenics)
- [GymnasticBodies Front Pull](https://www.gymnasticbodies.com/exercises/front-pull/)
- [GymnasticBodies Back Lever](https://www.gymnasticbodies.com/exercises/back-lever/)
- [GymnasticBodies German Hang Pull / Skin-the-Cat](https://www.gymnasticbodies.com/exercises/german-hang-pull-aka-skin-the-cat/)
- [Caliverse Skin the Cat](https://www.caliverse.app/exercises/skin-the-cat-150)
- [GymnasticBodies 360 Pulls](https://www.gymnasticbodies.com/forum/topic/263-360-pulls-a-multi-plane-pulling-exercise/)
- [The Movement Athlete 360 Pull](https://themovementathlete.com/advanced-back-lever-progressions/)
- [Beyond Movement 360 Pull](https://beyondmovement.com.au/skills/360-pull)
- [Scapular Stabilization RCT](https://ijspt.org/effectiveness-of-scapular-stabilization-versus-non-stabilization-stretching-on-shoulder-range-of-motion-a-randomized-clinical-trial/)

### Core, Compression, L-Sit

Grade: B+

Adequacy: A- in guide/slideshow; lower in node and plan notes.

What is good:

- The guide/slideshow layer is strong for active shoulders, ribs/pelvis control, no swing, controlled exits, and regress-before-break.
- No immediate P0 safety omission was found.

What is not enough:

- `L-Sit Max Hold` should not encourage pushing to form break.
- `cl.hanging-knee-raise` tier 5 feeding `cl.hanging-leg-raise` tier 3 is confusing.
- `cl.vertical-l-sit` needs a measurable visual standard or rename.
- L-sit "pelvis tilted back" cue needs tall chest/long spine so it does not cue a collapsed hold.
- Anatomy claims like "lower abs emphasis" should be softened into actual movement cues.

Evidence-backed cue additions:

- L-sit: press down, elbows locked, shoulders away from ears, hips lifted, chest tall while ribs stay braced.
- Raises/toes-to-bar: start from a still active hang; curl tailbone toward ribs; lower slowly enough that descent does not create the next swing.
- Hollow/rollout/plank: rep ends when lumbar arch, hip pike, shoulder collapse, or breath-holding takes over.
- Dragon flag: anchor shoulders/lats, move as one line, regress when hips pike or low back arches.

Key sources:

- [GMB L-Sit Progression](https://gmb.io/l-sit/)
- [ACE Fitness: Stuart McGill's Big Three](https://www.acefitness.org/resources/pros/expert-articles/7077/low-back-exercises-stuart-mcgill-s-big-three/?topicScope=corrective-exercise)
- [McGill, Low Back Exercises](https://pubmed.ncbi.nlm.nih.gov/9672547/)
- [Core Stabilization Exercise Prescription](https://pmc.ncbi.nlm.nih.gov/articles/PMC3806181/)
- [Caliverse Skin the Cat](https://www.caliverse.app/exercises/skin-the-cat-150)
- [Calisthenics.com Skin the Cat](https://calisthenics.com/exercise/skin-the-cat/)
- [Caliverse Front Lever](https://www.caliverse.app/exercises/front-lever-46)

### Legs, Pistols, Nordics, Jumping

Grade: B+

Adequacy: 7.5/10 overall.

What is good:

- Guides and slides cue foot pressure, knee tracking, bracing, controlled eccentrics, pain-free range, and regressions.
- Pistol and Nordic direction is mostly correct.

What is not enough:

- Plyometric and Nordic tier ladders encourage too much fatigue volume.
- Floor-to-ceiling squat slideshow does not match the supine no-hands node.
- Leg extension identity conflicts between open-chain/band extension and reverse-Nordic style bodyweight knee extension.
- "Front knee past toes" should not be framed as inherently bad.
- Generic leg exercise explainers are sparse.

Evidence-backed cue additions:

- Squat/goblet: drive through tripod foot; heel stays heavy, big toe stays down.
- Split/BSS: knee may travel forward if heel stays down and knee tracks toes; uncontrolled inward collapse is the fault.
- Pistol/shrimp: pelvis square, free leg active, regress before heel lifts or hip twists.
- Nordic: low volume, catch before free-fall, pad knees, glutes/ribs set before each eccentric.
- Jumps: set ends when height, quiet landing, or knee alignment fades; step down from boxes.
- Calf raise: full stretch to full top, ankle vertical, load gradually.

Key sources:

- [Fry et al., Knee Travel and Squat Torques](https://pubmed.ncbi.nlm.nih.gov/14636100/)
- [Schoenfeld, Squat Kinematics/Kinetics](https://pubmed.ncbi.nlm.nih.gov/20182386/)
- [Nordic Hamstring Injury Reduction Meta-Analysis](https://pubmed.ncbi.nlm.nih.gov/30808663/)
- [Nordic Volume/Adaptation Review](https://pubmed.ncbi.nlm.nih.gov/31502142/)
- [Plyometric Programming/Landing Concepts](https://pmc.ncbi.nlm.nih.gov/articles/PMC4637913/)
- [NASM Box Jumps](https://www.nasm.org/resource-center/exercise-library/box-jumps)
- [Medial Knee Displacement / Valgus Mechanics](https://pubmed.ncbi.nlm.nih.gov/23068590/)
- [Single-Leg Squat Mechanics](https://pmc.ncbi.nlm.nih.gov/articles/PMC8016417/)
- [Achilles Loading in Heel Raises](https://pmc.ncbi.nlm.nih.gov/articles/PMC5343533/)
- [Patellofemoral Loading in Leg Extension](https://pubmed.ncbi.nlm.nih.gov/8346760/)
- [Glute Medius Rehab EMG](https://pubmed.ncbi.nlm.nih.gov/30747561/)

### Handstand, Presses, One-Arm Handstand

Grade: C+

Adequacy: 6.5/10.

What is good:

- Wall and freestanding handstand guide/slideshow content is solid.
- Press guides are better than quick node copy.

What is not enough:

- OAH is the weakest elite branch. It needs more milestones and much deeper coaching.
- `hs.wall-plank` has a shoulder-elevation wording contradiction.
- `hs.headstand` is too casual for neck risk.
- Wall-supported OAH should use chest-to-wall/side-wall/fingertip support language rather than back-against-wall leaning.
- Press nodes need shoulders-past-wrists, compression, hips-over-hands, silent float, and top-pause standards.

Evidence-backed cue additions:

- Wall/handstand: push floor away; shoulders elevate/upwardly rotate; ribs down; neck long.
- Balance: fingertips brake overbalance, palm heel helps underbalance.
- Headstand: hands and crown form a triangle; palms press so head is light; enter and exit through tuck; no kicking.
- Presses: lean shoulders past wrists before feet leave; feet float silently; hips rise over hands before legs close; pause in stacked handstand.
- OAH: close-hand straddle -> weight shift -> side flexion/flag -> full fingertips -> two-finger tent -> one-finger tent -> off-hand float.

Key sources:

- [GymnasticBodies: Handstands for Beginners](https://www.gymnasticbodies.com/handstands-for-beginners-cues-for-success/)
- [GymnasticBodies: Wall Handstand](https://www.gymnasticbodies.com/exercises/wall-handstand/)
- [American Gymnast: Developing a Rock-Solid Handstand](https://www.american-gymnast.com/developing-a-rock-solid-handstand/)
- [NRG Foundation Handstand PDF](https://www.nrgq.co.uk/wp-content/uploads/2018/12/Foundation_Teaching-Progressions-HANDSTAND.pdf)
- [CrossFit: The Straddle Press](https://www.crossfit.com/essentials/the-straddle-press)
- [Handstand Factory: Are You Ready for the One-Arm Handstand?](https://handstandfactory.com/articles/are-your-ready-for-the-one-arm-handstand/)
- [GMB One-Arm Handstand](https://gmb.io/oahs/)
- [GymnasticBodies: 1-Finger 1-Arm Handstand](https://www.gymnasticbodies.com/exercises/1-finger-1-arm-handstand/)
- [Cirque Physio: Scapular Position Overhead](https://www.cirquephysio.com/blog/ditching-down-and-back)
- [Wrist Pain in Gymnasts Review](https://pubmed.ncbi.nlm.nih.gov/28902754/)
- [NRG Headstand Teaching Progressions PDF](https://www.nrgq.co.uk/wp-content/uploads/2018/12/Developmental_Teaching-Progressions-HEADSTAND.pdf)

### Planche And Arm Balances

Grade: B+

Adequacy: B.

What is good:

- The path is coherent: crow/crane -> tuck planche -> straddle -> half-lay -> full.
- Elbow lever is mostly separated from bent-arm planche in the guide/slideshow.
- The detailed planche guide is much better than quick node copy.

What is not enough:

- `cal.tuck-planche-pushup` is gated too loosely.
- Full planche quick cue says hips above shoulder height, which can encourage piking.
- Pseudo-planche hand angle should be tolerance-based, not mandatory hands backward for everyone.
- Raw straddle/half-lay cues should mention locked elbows and protracted/depressed scapulae.
- Bent-arm planche should explicitly say no elbow shelf wedged into hips.

Evidence-backed cue additions:

- Shoulders travel forward of hands/wrists before the feet float.
- Elbows locked for straight-arm planche holds; elbow pits face forward.
- Scapulae protracted and depressed; push floor/bars away.
- Ribs down, posterior pelvic tilt, glutes/quads squeezed; avoid banana back.
- Stop when elbows soften, hips drop, or wrist pain sharpens.
- Elbow lever rests on anchored elbows; bent-arm planche removes that hip/abdomen shelf.

Key sources:

- [GMB Planche](https://gmb.io/planche/)
- [GMB Crow Pose](https://gmb.io/crow-pose/)
- [Calisthenics World Elbow Lever](https://calisthenicsworld.org/elbow-lever/)
- [FIG MAG Code 2025-2028](https://www.gymnastics.sport/publicdir/rules/files/en_1.1%20-%20MAG%20CoP%202025-2028.pdf)
- [MyCodeOfPoints Planche/Support Scale](https://www.mycodeofpoints.com/skills/mag-rings-eg2-support-scale-planche-2-s-ee722a43/)
- [Wrist Loading Study](https://pubmed.ncbi.nlm.nih.gov/41133562/)

## Recommended Implementation Order

1. Fix factual/identity errors first.

   `cl.three-sixty-pulls`, German hang routing, HSPU head path, full planche hip cue, leg extension identity, floor-to-ceiling phases.

2. Fix unsafe or misleading high-risk shorthand.

   OAH, headstand, release skills, one-arm pulling, wall plank shoulder wording, plyo/Nordic fatigue targets.

3. Fix plan/graph mismatches.

   Tuck planche push-up gating, bench dip routing, German hang versus skin-the-cat plans, tuck planche push-up plan, proof-name mismatches for press work.

4. Populate in-session cue overrides.

   Add `ExerciseExplainerLibrary.formCues` entries for high-use drills and high-risk skills.

5. Promote the best guide language into node cards.

   The guide tabs already contain much of the good coaching. The quick cards should not sound like a separate, weaker product.

6. Add content coverage tests.

   High-risk nodes should fail tests if they lack guide content, phase content, assistance/regression, stop criteria, and non-generic cue copy.

## Final Answer To The User Question

No, the form cues are not uniformly enough as-is.

They are good enough as a foundation in branches like core, legs, planche, push, and pulling if the user opens the detailed guide pages. They are not enough from the quick node cards or in-session explainer alone. The weakest and most urgent areas are OAH, 360 pulls, German hang routing, HSPU head path, release skills, one-arm pulling, planche quick-card wording, and several plan/graph mismatches.

The next content pass should be evidence-backed rewriting, not adding more nodes.
