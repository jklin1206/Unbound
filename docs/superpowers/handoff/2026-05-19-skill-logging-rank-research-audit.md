# UNBOUND Skill Logging + Rank Data Audit

Generated from local Swift source. Live skills: 135. Every live skill has a tier table entry with 9 ranks.

## Evaluator Reality
- Workout skill logs store exercise name, set weight kg, reps, RPE, warmup flag.
- Skill sessions and skill quick logs save SessionLog entries, including holdSeconds, but RankService currently does not read sessionLogs when evaluating skill tier crossings.
- Cardio logs store type, duration minutes, distance km, avg HR, RPE, notes, date, but skill-tier criteria do not currently evaluate CardioSession.
- TierCriterion supports reps, seconds, weightKg, bodyweightRatio, variant, compound; however `.seconds` currently always returns false in TierCriterionEvaluator.
- Fixed in follow-up implementation: weighted/carry tier tables now use `.exerciseBodyweightRatio(r, exerciseName:)` for exercise-scoped load ratios. The old `.bodyweightRatio` remains available for broad lift standards, but should not be paired with `.variant` for skill ranks.
- Therefore hold durations, run/row/bike performance, carry duration/distance, sled duration/distance, and side-specific standards are not fully machine-validated today.

## Coverage Counts
| Target type | Live skills | Current rank fidelity |
|---|---:|---|
| reps | 86 | mostly direct reps by exercise name |
| hold | 38 | proxy only until seconds are logged/evaluated |
| weightMultiplier | 4 | exercise-scoped load-ratio validation after follow-up fix |
| carry | 3 | partial load-ratio, no duration/distance |
| steps | 4 | proxy only; no cardio result validation |

## Research-Backed Standards To Use
- Strength and weighted-skill ranks should use specific, progressive, measurable outcomes: exact exercise variant, reps, load, and bodyweight-scaled load where appropriate. This follows the ACSM resistance-training progression model: overload, specificity, and progression need to match the tested quality.
- Hold skills should rank by exact hold duration in the exact body shape. A hold target cannot be validated by "any log exists" or by unrelated proxy reps.
- Cardio skills should rank by the actual event result: distance or calories plus elapsed time, with modality stored separately for rower, running, bike, and assault bike work.
- Carries and sled work should rank by load ratio plus duration or distance. Load alone does not prove the skill because the standard is the carried or pushed task.
- Plyometric and explosive skills should be validated by low-fatigue quality reps or objective event marks, not high-rep fatigue standards. Volume should stop when landing, rhythm, or position quality drops.
- Side-specific skills need side-aware logging. A single best set cannot prove left and right side standards unless both sides are captured.

## Implementation Priority
1. Done: fix load ratios with `.exerciseBodyweightRatio(r, exerciseName:)`.
2. Feed SessionLog data into tier evaluation so skill TRAIN and quick-log flows can advance ranks.
3. Convert hold skills from `variant + proxy reps` to exact hold-second criteria.
4. Add cardio result criteria that evaluate CardioSession distance/calories plus elapsed time.
5. Add carry/sled criteria for load ratio plus duration or distance.
6. Add side-aware criteria for unilateral standards.
7. Revisit explosive/plyometric rank targets so they reward clean low-fatigue reps, not fatigue volume.

## Criterion Examples
Good rep criterion:
```swift
.reps(8, exerciseName: "pullup")
```
This proves the user logged one working set of at least 8 pullups.

Good weighted criterion:
```swift
.exerciseBodyweightRatio(0.5, exerciseName: "weighted pullup")
```
This proves the added load on weighted pullups reached 50% of bodyweight. A heavy squat cannot satisfy it.

Bad weighted proxy:
```swift
.compound([.variant("weighted pullup"), .bodyweightRatio(0.5)])
```
This can prove that weighted pullups exist and that some exercise was heavy, but those facts may come from different logs.

Current hold proxy:
```swift
.compound([.variant("dead hang"), .reps(8, exerciseName: "pullup")])
```
This is still a proxy. It proves hang exposure and pull strength, but not a timed dead hang.

Target hold criterion after SessionLog is wired in:
```swift
.holdSeconds(45, exerciseName: "dead hang")
```

Target cardio criterion after CardioSession is wired in:
```swift
.distanceTime(activity: "run", distanceMeters: 1609, maxSeconds: 420)
```

Target carry criterion after distance/time fields exist:
```swift
.carryLoadRatio(1.0, exerciseName: "farmer carry", minSeconds: 60, minDistanceMeters: 40)
```

## Sources Checked
- ACSM, "Progression Models in Resistance Training for Healthy Adults" / updated resistance-training progression position stand: https://pubmed.ncbi.nlm.nih.gov/19204579/
- NSCA, plyometric exercise guidance: https://www.nsca.com/education/articles/kinetic-select/plyometric-exercises/
- Concept2 rowing technique guidance: https://www.concept2.com/training/improve-your-rowing-technique
- CDC intensity/RPE guidance for aerobic effort: https://www.cdc.gov/physical-activity-basics/measuring/index.html
- CrossFit strict muscle-up foundations, useful as one skill-specific reference pattern for prerequisites and strict form standards: https://www.crossfit.com/essentials/strict-muscle-up-foundations

## Full Live Skill Matrix
| Skill | Title | App target standard | Initiate | Forged | Ascendant | Fidelity |
|---|---|---|---|---|---|---|
| ld.goblet-20 | Half Squat | reps(exercise: "half squat", count: 15) | any log: goblet squat | any log: goblet squat + load >= 30% BW | any log: goblet squat + load >= 100% BW | FIXED: exercise-scoped load ratio |
| ld.split-squat | Split Squat | reps(exercise: "split squat", count: 10) | 5 reps split squat | 15 reps split squat | 40 reps split squat + 15 reps bulgarian split squat | DIRECT: best single-set reps by exercise name |
| ld.bulgarian-split-squat | Bulgarian Split Squat | reps(exercise: "bulgarian split squat", count: 10) | 3 reps bulgarian split squat | 10 reps bulgarian split squat | 40 reps bulgarian split squat | DIRECT: best single-set reps by exercise name |
| ld.shrimp-squat | Shrimp Squat | reps(exercise: "shrimp squat", count: 3) | 1 reps shrimp squat | 5 reps shrimp squat | 20 reps shrimp squat | DIRECT: best single-set reps by exercise name |
| ld.pistol-squat | Pistol Squat | reps(exercise: "pistol squat", count: 5) | 1 reps pistol squat | 5 reps pistol squat | 20 reps pistol squat | DIRECT: best single-set reps by exercise name |
| ld.weighted-pistol | Weighted Pistol | reps(exercise: "weighted pistol", count: 3, load: "0.5x bw") | any log: weighted pistol | any log: weighted pistol + load >= 35% BW | any log: weighted pistol + load >= 125% BW | FIXED: exercise-scoped load ratio |
| pp.dead-hang | Dead Hang | hold(exercise: "dead hang", seconds: 30) | any log: dead hang | any log: dead hang + 3 reps pullup | any log: dead hang + 15 reps pullup | PROXY: no seconds validation; variant/proxy reps only |
| pp.pullup | Pull-Up | reps(exercise: "pullup", count: 5) | 1 reps pullup | 5 reps pullup | 12 reps pullup | DIRECT: best single-set reps by exercise name |
| pp.strict-pullup | Strict Pull-Up | reps(exercise: "strict pullup", count: 5) | 1 reps pullup | 8 reps pullup | 20 reps pullup | DIRECT: best single-set reps by exercise name |
| pp.archer-pullup | Archer Pull-Up | reps(exercise: "archer pullup", count: 3) | 1 reps archer pullup | 4 reps archer pullup | 15 reps archer pullup | DIRECT: best single-set reps by exercise name |
| pp.weighted-pullup | Weighted Pull-Up | weightMultiplier(exercise: "weighted pullup", multiplier: 0.5) | any log: weighted pullup | any log: weighted pullup + load >= 35% BW | any log: weighted pullup + load >= 125% BW | PARTIAL: load ratio yes; reps sometimes implicit/proxy |
| pp.oap-negative | One-Arm Pull-Up Negative | reps(exercise: "one-arm pullup negative", count: 3) | 1 reps one-arm pullup negative | 4 reps one-arm pullup negative | 12 reps one-arm pullup negative | DIRECT: best single-set reps by exercise name |
| pp.one-arm-pullup | One-Arm Pull-Up | reps(exercise: "one-arm pullup", count: 1) | 1 reps one-arm pullup | 3 reps one-arm pullup | any log: weighted pullup + 10 reps one-arm pullup + load >= 75% BW | FIXED: exercise-scoped load ratio |
| pp.muscle-up | Muscle-Up | reps(exercise: "muscle-up", count: 1) | 5 reps pullup + 5 reps straight bar dip | 1 reps muscle-up | 12 reps muscle-up | DIRECT: best single-set reps by exercise name |
| pp.ring-muscle-up | Ring Muscle-Up | reps(exercise: "ring muscle-up", count: 1) | 1 reps ring muscle-up | 4 reps ring muscle-up | 12 reps ring muscle-up | DIRECT: best single-set reps by exercise name |
| cal.plank-30 | Plank | hold(exercise: "plank", seconds: 30) | any log: plank | any log: plank + 5 reps pushup | any log: plank + 80 reps pushup | PROXY: no seconds validation; variant/proxy reps only |
| cal.l-sit-10 | L-Sit | hold(exercise: "l-sit", seconds: 10) | any log: l-sit | any log: l-sit + any log: leg raise | any log: l-sit + 25 reps leg raise | PROXY: no seconds validation; variant/proxy reps only |
| cal.pushup | Push-Up | reps(exercise: "pushup", count: 10) | 3 reps pushup | 15 reps pushup | 100 reps pushup | DIRECT: best single-set reps by exercise name |
| cal.5-dips | Dip | reps(exercise: "dip", count: 5) | 2 reps dip | 5 reps dip | 30 reps dip | DIRECT: best single-set reps by exercise name |
| cal.ring-dip | Ring Dip | reps(exercise: "ring dip", count: 5) | 1 reps ring dip | 5 reps ring dip | 20 reps ring dip | DIRECT: best single-set reps by exercise name |
| cal.diamond-pushup | Diamond Push-Up | reps(exercise: "diamond pushup", count: 10) | 3 reps diamond pushup | 10 reps diamond pushup | 50 reps diamond pushup | DIRECT: best single-set reps by exercise name |
| cal.pseudo-planche-pushup | Pseudo-Planche Push-Up | reps(exercise: "pseudo-planche pushup", count: 5) | 5 reps pushup | 10 reps pseudo-planche pushup | 30 reps pseudo-planche pushup + 3 reps tuck planche pushup | DIRECT: best single-set reps by exercise name |
| pl.tuck-planche | Tuck Planche | hold(exercise: "tuck planche", seconds: 5) | 10 reps pseudo-planche pushup | any log: tuck planche + 5 reps pseudo-planche pushup | any log: tuck planche + any log: straddle planche + 5 reps tuck planche pushup | PROXY: no seconds validation; variant/proxy reps only |
| cal.tuck-planche-pushup | Tuck Planche Push-Up | reps(exercise: "tuck planche pushup", count: 3) | any log: tuck planche | 3 reps tuck planche pushup | any log: full planche + 10 reps tuck planche pushup | DIRECT: best single-set reps by exercise name |
| pl.straddle-planche | Straddle Planche | hold(exercise: "straddle planche", seconds: 5) | any log: tuck planche | any log: straddle planche + 5 reps tuck planche pushup | any log: straddle planche + 3 reps full planche pushup | PROXY: no seconds validation; variant/proxy reps only |
| pl.full-planche | Full Planche | hold(exercise: "full planche", seconds: 5) | any log: straddle planche | any log: full planche + 10 reps tuck planche pushup | any log: full planche + 5 reps full planche pushup | PROXY: no seconds validation; variant/proxy reps only |
| cal.handstand-pushup | Handstand Push-Up | reps(exercise: "handstand pushup", count: 1) | 3 reps wall hspu negative | 3 reps wall hspu | 12 reps wall hspu + 1 reps freestanding hspu | DIRECT: best single-set reps by exercise name |
| cal.ninety-degree-pushup | Ninety-Degree Push-Up | reps(exercise: "90 degree pushup", count: 1) | any log: tuck planche | 1 reps 90-degree pushup | 8 reps 90-degree pushup + 3 reps freestanding hspu | DIRECT: best single-set reps by exercise name |
| cal.clapping-handstand-pushup | Clapping Handstand Push-Up | reps(exercise: "clapping handstand pushup", count: 1) | 3 reps wall hspu | 1 reps clapping handstand pushup | 8 reps clapping handstand pushup + 8 reps freestanding hspu | DIRECT: best single-set reps by exercise name |
| cal.pike-pushup | Pike Push-Up | reps(exercise: "pike pushup", count: 10) | 5 reps pushup | 10 reps pike pushup | 30 reps pike pushup + 10 reps elevated pike pushup | DIRECT: best single-set reps by exercise name |
| cal.elevated-pike-pushup | Elevated Pike Push-Up | reps(exercise: "elevated pike pushup", count: 10) | 5 reps pike pushup | 10 reps elevated pike pushup | 30 reps elevated pike pushup + 1 reps wall hspu | DIRECT: best single-set reps by exercise name |
| hs.wall-handstand-30 | Wall Handstand | hold(exercise: "wall handstand", seconds: 30) | any log: wall handstand | any log: wall handstand + 3 reps handstand pushup | any log: wall handstand + 20 reps handstand pushup | PROXY: no seconds validation; variant/proxy reps only |
| hs.freestanding-hs-30 | Handstand | hold(exercise: "freestanding handstand", seconds: 30) | any log: freestanding handstand | any log: freestanding handstand + 3 reps tuck press | any log: freestanding handstand + 3 reps press to handstand | PROXY: no seconds validation; variant/proxy reps only |
| oah.one-arm-handstand-5s | One-Arm Handstand | hold(exercise: "one-arm handstand", seconds: 5) | any log: freestanding handstand + 8 reps wall hspu | any log: wall-supported one-arm handstand + 7 reps freestanding hspu | any log: one-arm handstand + any log: wall-supported one-arm handstand + 10 reps freestanding hspu | PROXY: no seconds validation; variant/proxy reps only |
| oah.full-one-arm-handstand | Full One-Arm Handstand | hold(exercise: "full one arm handstand", seconds: 5) | any log: one-arm handstand + any log: wall-supported one-arm handstand | any log: full one arm handstand + 5 reps freestanding hspu | any log: full one arm handstand + any log: one-arm handstand + 15 reps freestanding hspu | PROXY: no seconds validation; variant/proxy reps only |
| cl.hollow-body-30 | Hollow Body | hold(exercise: "hollow body hold", seconds: 30) | any log: hollow body hold | any log: hollow body hold + 5 reps hanging knee raise | any log: hollow body hold + 30 reps hanging knee raise | PROXY: no seconds validation; variant/proxy reps only |
| cl.hanging-knee-raise | Hanging Knee Raise | reps(exercise: "hanging knee raise", count: 10) | 3 reps hanging knee raise | 10 reps hanging knee raise | 40 reps hanging knee raise | DIRECT: best single-set reps by exercise name |
| cl.hanging-leg-raise | Hanging Leg Raise | reps(exercise: "hanging leg raise", count: 10) | 2 reps hanging leg raise | 10 reps hanging leg raise | 40 reps hanging leg raise | DIRECT: best single-set reps by exercise name |
| cl.toes-to-bar | Toes-to-Bar | reps(exercise: "toes to bar", count: 5) | 1 reps toes to bar | 5 reps toes to bar | 25 reps toes to bar | DIRECT: best single-set reps by exercise name |
| cl.standing-ab-rollout | Standing Ab Rollout | reps(exercise: "standing ab rollout", count: 5) | 1 reps ab wheel standing | 5 reps ab wheel standing | 25 reps ab wheel standing | DIRECT: best single-set reps by exercise name |
| cl.dragon-flag | Dragon Flag | reps(exercise: "dragon flag", count: 5) | 1 reps dragon flag negative | 5 reps dragon flag | 20 reps dragon flag | DIRECT: best single-set reps by exercise name |
| cl.tuck-front-lever | Tuck Front Lever | hold(exercise: "tuck front lever", seconds: 10) | any log: hollow body hold | any log: tuck front lever | any log: tuck front lever + 25 reps hanging leg raise | PROXY: no seconds validation; variant/proxy reps only |
| cl.straddle-front-lever | Straddle Front Lever | hold(exercise: "straddle front lever", seconds: 5) | any log: tuck front lever | any log: straddle front lever | any log: straddle front lever + 20 reps toes to bar | PROXY: no seconds validation; variant/proxy reps only |
| cl.full-front-lever | Full Front Lever | hold(exercise: "front lever", seconds: 5) | any log: tuck front lever | any log: front lever | any log: front lever + 20 reps toes to bar | PROXY: no seconds validation; variant/proxy reps only |
| cl.straddle-back-lever | Straddle Back Lever | hold(exercise: "straddle back lever", seconds: 5) | any log: tuck back lever | any log: straddle back lever | any log: straddle back lever + 12 reps skin the cat | PROXY: no seconds validation; variant/proxy reps only |
| cl.full-back-lever | Full Back Lever | hold(exercise: "back lever", seconds: 5) | any log: tuck back lever | any log: back lever | any log: back lever + 12 reps skin the cat | PROXY: no seconds validation; variant/proxy reps only |
| co.bw-farmer-carry | Farmer Carry | carry(exercise: "farmer carry", seconds: 60, load: "bw") | any log: farmer carry | any log: farmer carry + load >= 50% BW | any log: farmer carry + load >= 100% BW | PARTIAL: load ratio yes; carry/sled duration/distance no |
| co.1.5x-farmer-carry | Heavy Farmer Carry | carry(exercise: "farmer carry", seconds: 60, load: "1.5x bw") | any log: farmer carry + load >= 75% BW | any log: farmer carry + load >= 110% BW | any log: farmer carry + load >= 150% BW | PARTIAL: load ratio yes; carry/sled duration/distance no |
| co.dead-hang-45 | Long Dead Hang | hold(exercise: "dead hang", seconds: 45) | any log: dead hang | any log: dead hang + 3 reps pullup | any log: dead hang + 15 reps pullup | PROXY: no seconds validation; variant/proxy reps only |
| co.dead-hang-60 | Max Dead Hang | hold(exercise: "dead hang", seconds: 60) | any log: dead hang + 3 reps pullup | any log: dead hang + 10 reps pullup | any log: dead hang + 25 reps pullup | PROXY: no seconds validation; variant/proxy reps only |
| co.sled-push | Sled Push | carry(exercise: "sled push", seconds: 30, load: "2x bw") | any log: sled push | any log: sled push + load >= 75% BW | any log: sled push + load >= 200% BW | PARTIAL: load ratio yes; carry/sled duration/distance no |
| co.400m-row | Rower Sprint | steps(exercise: "row 400m", count: 1) | any log: row 400m | any log: row 400m + 3 reps pullup | any log: row 400m + 15 reps pullup | PROXY: no pace/calorie/distance validation in skill ranks |
| co.mile-sub-7 | Fast Mile | steps(exercise: "run 1 mile", count: 1) | any log: run 1 mile | any log: run 1 mile + 10 reps pushup | any log: run 1 mile + 60 reps pushup | PROXY: no pace/calorie/distance validation in skill ranks |
| co.5k-sub-22 | Fast 5K | steps(exercise: "run 5k", count: 1) | any log: run 5k + 10 reps pushup | any log: run 5k + 25 reps pushup | any log: run 5k + 75 reps pushup | PROXY: no pace/calorie/distance validation in skill ranks |
| co.2x-farmer-carry | Elite Farmer Carry | weightMultiplier(exercise: "farmer carry", multiplier: 2.0) | any log: farmer carry + load >= 100% BW | any log: farmer carry + load >= 150% BW | any log: farmer carry + load >= 200% BW | PARTIAL: load ratio yes; reps sometimes implicit/proxy |
| co.assault-bike-30 | Assault Bike Sprint | steps(exercise: "assault bike 30 cal", count: 1) | any log: assault bike 30 cal | any log: assault bike 30 cal + 10 reps pushup | any log: assault bike 30 cal + 12 reps pullup | PROXY: no pace/calorie/distance validation in skill ranks |
| pp.chin-up | Chin-Up | reps(exercise: "chin-up", count: 5) | 1 reps chin-up | 5 reps chin-up | 12 reps chin-up | DIRECT: best single-set reps by exercise name |
| pp.strict-chin-up | Strict Chin-Up | reps(exercise: "chin-up", count: 8) | 1 reps chin-up | 8 reps chin-up | 20 reps chin-up | DIRECT: best single-set reps by exercise name |
| pp.weighted-chin-up | Weighted Chin-Up | weightMultiplier(exercise: "weighted chin-up", multiplier: 0.5) | any log: weighted chin-up | any log: weighted chin-up + load >= 25% BW | any log: weighted chin-up + load >= 100% BW | PARTIAL: load ratio yes; reps sometimes implicit/proxy |
| pp.l-sit-chin-up | L-Sit Chin-Up | reps(exercise: "l-sit chin-up", count: 5) | 1 reps l-sit chin-up | 4 reps l-sit chin-up | 12 reps l-sit chin-up | DIRECT: best single-set reps by exercise name |
| pp.wide-pullup | Wide Pull-Up | reps(exercise: "wide pullup", count: 5) | 1 reps wide pullup | 5 reps wide pullup | 20 reps wide pullup | DIRECT: best single-set reps by exercise name |
| pp.explosive-pullup | Explosive Pull-Up | reps(exercise: "explosive pullup", count: 3) | 1 reps explosive pullup | 4 reps explosive pullup | 12 reps explosive pullup | DIRECT: best single-set reps by exercise name |
| pp.clapping-pullup | Clapping Pull-Up | reps(exercise: "clapping pullup", count: 1) | 1 reps clapping pullup | 4 reps clapping pullup | 12 reps clapping pullup | DIRECT: best single-set reps by exercise name |
| cal.incline-pushup | Incline Push-Up | reps(exercise: "incline pushup", count: 10) | 5 reps incline pushup | 20 reps incline pushup | 100 reps incline pushup | DIRECT: best single-set reps by exercise name |
| cal.decline-pushup | Decline Push-Up | reps(exercise: "decline pushup", count: 10) | 3 reps decline pushup | 12 reps decline pushup | 75 reps decline pushup | DIRECT: best single-set reps by exercise name |
| cal.sphinx-pushup | Sphinx Push-Up | reps(exercise: "sphinx pushup", count: 8) | 2 reps sphinx pushup | 8 reps sphinx pushup | 50 reps sphinx pushup | DIRECT: best single-set reps by exercise name |
| cal.archer-pushup | Archer Push-Up | reps(exercise: "archer pushup", count: 3) | 1 reps archer pushup | 5 reps archer pushup | 25 reps archer pushup | DIRECT: best single-set reps by exercise name |
| cal.one-arm-pushup | One-Arm Push-Up | reps(exercise: "one-arm pushup", count: 1) | 1 reps one-arm pushup | 5 reps one-arm pushup | 20 reps one-arm pushup | DIRECT: best single-set reps by exercise name |
| cal.explosive-pushup | Explosive Push-Up | reps(exercise: "explosive pushup", count: 5) | 2 reps explosive pushup | 5 reps explosive pushup | 25 reps explosive pushup | DIRECT: best single-set reps by exercise name |
| cal.clapping-pushup | Clapping Push-Up | reps(exercise: "clapping pushup", count: 3) | 1 reps clapping pushup | 5 reps clapping pushup | 25 reps clapping pushup | DIRECT: best single-set reps by exercise name |
| cal.floating-pike-pushup | Floating Pike Push-Up | reps(exercise: "floating pike pushup", count: 3) | 1 reps floating pike pushup | 4 reps floating pike pushup | 16 reps floating pike pushup | DIRECT: best single-set reps by exercise name |
| cal.bench-dip | Bench Dip | reps(exercise: "bench dip", count: 10) | 5 reps bench dip | 15 reps bench dip | 75 reps bench dip | DIRECT: best single-set reps by exercise name |
| cal.triple-clap-pushup | Triple Clap Push-Up | reps(exercise: "triple clap pushup", count: 1) | 1 reps triple clap pushup | 4 reps triple clap pushup | 15 reps triple clap pushup | DIRECT: best single-set reps by exercise name |
| ld.calf-raise | Calf Raise | reps(exercise: "calf raise", count: 20) | 8 reps calf raise | 20 reps calf raise | 100 reps calf raise | DIRECT: best single-set reps by exercise name |
| ld.weighted-sl-calf | Weighted Single-Leg Calf Raise | reps(exercise: "single-leg calf raise", count: 10, load: "0.5x bw") | any log: single-leg calf raise | any log: single-leg calf raise + load >= 35% BW | any log: single-leg calf raise + load >= 140% BW | FIXED: exercise-scoped load ratio |
| ld.box-jump | Box Jump | reps(exercise: "box jump", count: 5) | 2 reps box jump | 5 reps box jump | 25 reps box jump | DIRECT: best single-set reps by exercise name |
| ld.jumping-squat | Jumping Squat | reps(exercise: "jumping squat", count: 10) | 3 reps jumping squat | 10 reps jumping squat | 40 reps jumping squat | DIRECT: best single-set reps by exercise name |
| ld.weighted-split-squat | Weighted Split Squat | reps(exercise: "weighted split squat", count: 8, load: "0.25x bw") | any log: weighted split squat | any log: weighted split squat + load >= 35% BW | any log: weighted split squat + load >= 125% BW | FIXED: exercise-scoped load ratio |
| ld.fire-hydrant | Fire Hydrant | reps(exercise: "fire hydrant", count: 15) | 5 reps fire hydrant | 15 reps fire hydrant | 50 reps fire hydrant | DIRECT: best single-set reps by exercise name |
| ld.single-leg-glute-bridge | Single-Leg Glute Bridge | reps(exercise: "single-leg glute bridge", count: 10) | 3 reps single-leg glute bridge | 10 reps single-leg glute bridge | 40 reps single-leg glute bridge | DIRECT: best single-set reps by exercise name |
| ld.flying-kickback | Leg Kickback | reps(exercise: "leg kickback", count: 12) | 5 reps fire kickback | 12 reps fire kickback | 40 reps fire kickback | DIRECT: best single-set reps by exercise name |
| ld.leg-extensions | Leg Extensions | reps(exercise: "leg extensions", count: 15) | 8 reps leg extension | 15 reps leg extension | 40 reps leg extension + 10 reps sissy squat | DIRECT: best single-set reps by exercise name |
| ld.advancing-nordic-curl | Advanced Nordic Hip Hinge | reps(exercise: "advanced nordic hip hinge", count: 5) | 1 reps nordic curl | 4 reps nordic curl | 12 reps nordic curl | DIRECT: best single-set reps by exercise name |
| ld.floor-to-ceiling-squat | Floor to Ceiling Squat | reps(exercise: "floor to ceiling squat", count: 1) | 1 reps floor to ceiling squat | 4 reps floor to ceiling squat | 16 reps floor to ceiling squat | DIRECT: best single-set reps by exercise name |
| cl.crunch | Crunch | reps(exercise: "crunch", count: 20) | 5 reps crunch | 20 reps crunch | 100 reps crunch | DIRECT: best single-set reps by exercise name |
| cl.reverse-crunch | Reverse Crunch | reps(exercise: "reverse crunch", count: 15) | 5 reps reverse crunch | 15 reps reverse crunch | 60 reps reverse crunch | DIRECT: best single-set reps by exercise name |
| cl.superman-plank | Superman Plank | hold(exercise: "superman plank", seconds: 15) | any log: superman plank | any log: superman plank + any log: bird dog plank | any log: superman plank + 50 reps crunch | PROXY: no seconds validation; variant/proxy reps only |
| cl.extended-plank | Extended Plank | hold(exercise: "extended plank", seconds: 15) | any log: extended plank | any log: extended plank + 5 reps ab wheel kneeling | any log: extended plank + 25 reps ab wheel kneeling | PROXY: no seconds validation; variant/proxy reps only |
| cl.knee-ab-rollout | Knee Ab Rollout | reps(exercise: "ab wheel kneeling", count: 8) | 2 reps ab wheel kneeling | 8 reps ab wheel kneeling | 30 reps ab wheel kneeling | DIRECT: best single-set reps by exercise name |
| cl.levitation-crunch | Levitation Crunch | reps(exercise: "levitation crunch", count: 8) | 5 reps reverse crunch | 8 reps levitation crunch | 25 reps levitation crunch | DIRECT: best single-set reps by exercise name |
| cl.inverted-situp | Inverted Sit-Up | reps(exercise: "inverted sit-up", count: 5) | 3 reps decline sit-up | 5 reps inverted sit-up | 20 reps inverted sit-up | DIRECT: best single-set reps by exercise name |
| cl.skin-the-cat | Skin the Cat | reps(exercise: "skin the cat", count: 3) | 1 reps german hang | 3 reps skin the cat | 15 reps skin the cat | DIRECT: best single-set reps by exercise name |
| cl.german-hang | German Hang | hold(exercise: "german hang", seconds: 10) | any log: german hang | any log: german hang + 1 reps skin the cat | any log: german hang + 12 reps skin the cat | PROXY: no seconds validation; variant/proxy reps only |
| cl.three-sixty-pulls | 360-Degree Pulls | reps(exercise: "360-degree pulls", count: 1) | 5 reps hanging leg raise | 1 reps 360-degree pulls | 10 reps 360-degree pulls | DIRECT: best single-set reps by exercise name |
| hs.headstand | Headstand | hold(exercise: "headstand", seconds: 30) | any log: headstand | any log: headstand + any log: wall handstand | any log: headstand + 16 reps handstand pushup | PROXY: no seconds validation; variant/proxy reps only |
| hs.tuck-handstand | Tuck Handstand | hold(exercise: "tuck handstand", seconds: 5) | any log: tuck handstand | any log: tuck handstand + any log: freestanding handstand | any log: tuck handstand + 20 reps handstand pushup | PROXY: no seconds validation; variant/proxy reps only |
| hs.crow-pose | Crow Pose | hold(exercise: "crow pose", seconds: 15) | any log: crow pose | any log: crow pose + 10 reps pushup | any log: crow pose + any log: flying crow | PROXY: no seconds validation; variant/proxy reps only |
| hs.crane-pose | Crane Pose | hold(exercise: "crane pose", seconds: 10) | any log: crow pose | any log: crane pose + 5 reps handstand pushup | any log: crane pose + 5 reps tuck press | PROXY: no seconds validation; variant/proxy reps only |
| hs.flying-crow | Flying Crow Pose | hold(exercise: "flying crow", seconds: 5) | any log: crow pose | any log: flying crow + 5 reps handstand pushup | any log: flying crow + 5 reps tuck press | PROXY: no seconds validation; variant/proxy reps only |
| hs.elbow-lever | Elbow Lever | hold(exercise: "elbow lever", seconds: 10) | any log: elbow lever | any log: elbow lever + 10 reps pushup | any log: elbow lever + any log: one-arm elbow lever | PROXY: no seconds validation; variant/proxy reps only |
| hs.one-arm-elbow-lever | One-Arm Elbow Lever | hold(exercise: "one-arm elbow lever", seconds: 5) | any log: elbow lever | any log: one-arm elbow lever + 5 reps handstand pushup | any log: one-arm elbow lever + 5 reps tuck press | PROXY: no seconds validation; variant/proxy reps only |
| hs.tuck-press | Tuck Press to Handstand | reps(exercise: "tuck press", count: 3) | 1 reps tuck press | 5 reps tuck press | 15 reps tuck press + 15 reps handstand pushup | DIRECT: best single-set reps by exercise name |
| hs.straddle-press | Straddle Press to Handstand | reps(exercise: "straddle press", count: 3) | 1 reps straddle press | 5 reps straddle press | 15 reps straddle press + 5 reps press to handstand | DIRECT: best single-set reps by exercise name |
| hs.press-to-handstand | Press to Handstand | reps(exercise: "press to handstand", count: 1) | 1 reps tuck press | 1 reps press to handstand | 10 reps press to handstand + 15 reps handstand pushup | DIRECT: best single-set reps by exercise name |
| pl.bent-arm-planche | Bent Arm Planche | hold(exercise: "bent arm planche", seconds: 3) | any log: tuck planche | any log: bent arm planche + 5 reps tuck planche pushup | any log: bent arm planche + 5 reps full planche pushup + 1 reps 90 degree pushup | PROXY: no seconds validation; variant/proxy reps only |
| pl.half-lay-planche | Half-Lay Planche | hold(exercise: "half-lay planche", seconds: 3) | any log: tuck planche | any log: half-lay planche + any log: straddle planche | any log: half-lay planche + 5 reps full planche pushup | PROXY: no seconds validation; variant/proxy reps only |
| pp.incline-row | Incline Row | reps(exercise: "incline row", count: 12) | 5 reps incline row | 12 reps incline row | 40 reps incline row | DIRECT: best single-set reps by exercise name |
| pp.row | Row | reps(exercise: "inverted row", count: 10) | 3 reps inverted row | 10 reps inverted row | 30 reps inverted row | DIRECT: best single-set reps by exercise name |
| pp.decline-row | Decline Row | reps(exercise: "decline row", count: 10) | 3 reps decline row | 10 reps decline row | 30 reps decline row | DIRECT: best single-set reps by exercise name |
| pp.one-arm-row | One-Arm Row | reps(exercise: "one arm row", count: 5) | 3 reps one-arm row | 10 reps one-arm row | 25 reps one-arm row + 5 reps straddle row | DIRECT: best single-set reps by exercise name |
| pp.tuck-row | Tuck Row | reps(exercise: "tuck row", count: 8) | 2 reps tuck row | 8 reps tuck row | 20 reps tuck row | DIRECT: best single-set reps by exercise name |
| pp.straddle-row | Straddle Row | reps(exercise: "straddle row", count: 5) | 1 reps straddle row | 5 reps straddle row | 15 reps straddle row | DIRECT: best single-set reps by exercise name |
| pp.tuck-front-lever-pullup | Tuck Front Lever Pull-Up | reps(exercise: "tuck front lever pullup", count: 3) | 3 reps tuck row | 3 reps tuck front lever pullup | any log: front lever + 12 reps tuck front lever pullup | DIRECT: best single-set reps by exercise name |
| pp.heighted-chin-up | Heighted Chin-Up | reps(exercise: "heighted chin-up", count: 3) | 1 reps heighted chin-up | 4 reps heighted chin-up | 12 reps heighted chin-up | DIRECT: best single-set reps by exercise name |
| pp.one-arm-chin-up | One-Arm Chin-Up | reps(exercise: "one-arm chin-up", count: 1) | 1 reps one-arm chin-up | 3 reps one-arm chin-up | 8 reps one-arm chin-up | DIRECT: best single-set reps by exercise name |
| pp.strict-muscle-up | Strict Muscle-Up | reps(exercise: "strict muscle-up", count: 1) | 1 reps strict muscle-up | 3 reps strict muscle-up | 8 reps strict muscle-up | DIRECT: best single-set reps by exercise name |
| cal.bent-arm-press | Bent Arm Press | reps(exercise: "bent arm press", count: 3) | 1 reps bent arm press | 4 reps bent arm press | 12 reps bent arm press | DIRECT: best single-set reps by exercise name |
| ld.step-up | Step Up | reps(exercise: "step up", count: 15) | 5 reps step up | 15 reps step up | 50 reps step up | DIRECT: best single-set reps by exercise name |
| ld.deep-squat | Deep Squat | hold(exercise: "deep squat", seconds: 60) | any log: deep squat | any log: deep squat + 10 reps goblet squat | any log: deep squat + 40 reps goblet squat | PROXY: no seconds validation; variant/proxy reps only |
| ld.glute-bridge | Glute Bridge | reps(exercise: "glute bridge", count: 15) | 5 reps glute bridge | 15 reps glute bridge | 75 reps glute bridge | DIRECT: best single-set reps by exercise name |
| ld.weighted-bss | Weighted Bulgarian Split Squat | weightMultiplier(exercise: "weighted bss", multiplier: 0.5) | any log: weighted bss | any log: weighted bss + load >= 50% BW | any log: weighted bss + load >= 160% BW | PARTIAL: load ratio yes; reps sometimes implicit/proxy |
| ld.sissy-squat | Sissy Squat | reps(exercise: "sissy squat", count: 8) | 2 reps sissy squat | 8 reps sissy squat | 30 reps sissy squat | DIRECT: best single-set reps by exercise name |
| ld.nordic-hip-hinge | Nordic Hip Hinge | reps(exercise: "nordic hip hinge", count: 8) | 3 reps nordic hip hinge | 8 reps nordic hip hinge | 20 reps nordic hip hinge | DIRECT: best single-set reps by exercise name |
| ld.nordic-curl | Nordic Curl | reps(exercise: "nordic curl", count: 3) | 1 reps nordic curl | 5 reps nordic curl | 20 reps nordic curl | DIRECT: best single-set reps by exercise name |
| cl.bird-dog-plank | Bird Dog Plank | hold(exercise: "bird dog plank", seconds: 30) | any log: bird dog plank | any log: bird dog plank + any log: superman plank | any log: bird dog plank + 30 reps reverse crunch | PROXY: no seconds validation; variant/proxy reps only |
| cl.v-sit | V-Sit | hold(exercise: "v-sit", seconds: 10) | any log: hollow body hold | any log: v-sit | any log: v-sit + 20 reps toes to bar | PROXY: no seconds validation; variant/proxy reps only |
| cl.straddle-l-sit | Straddle L-Sit | hold(exercise: "straddle l-sit", seconds: 10) | any log: hollow body hold | any log: straddle l-sit | any log: straddle l-sit + 20 reps hanging leg raise | PROXY: no seconds validation; variant/proxy reps only |
| cl.dragon-flag-hip-raise | Dragon Flag Hip Raise | reps(exercise: "dragon flag hip raise", count: 8) | 3 reps reverse crunch | 8 reps dragon flag hip raise | 25 reps dragon flag hip raise | DIRECT: best single-set reps by exercise name |
| cl.decline-situp | Decline Sit-Up | reps(exercise: "decline sit-up", count: 15) | 5 reps decline sit-up | 15 reps decline sit-up | 60 reps decline sit-up | DIRECT: best single-set reps by exercise name |
| cl.knee-raise | Knee Raise | reps(exercise: "knee raise", count: 12) | 5 reps knee raise | 15 reps knee raise | 40 reps knee raise + 15 reps hanging knee raise | DIRECT: best single-set reps by exercise name |
| cl.leg-raise | Leg Raise | reps(exercise: "leg raise", count: 12) | 3 reps leg raise | 12 reps leg raise | 30 reps leg raise + 10 reps hanging leg raise | DIRECT: best single-set reps by exercise name |
| cl.semi-straddle-l-sit | Semi Straddle L-Sit | hold(exercise: "semi straddle l-sit", seconds: 10) | any log: l-sit | any log: semi-straddle l-sit | any log: semi-straddle l-sit + 15 reps toes to bar | PROXY: no seconds validation; variant/proxy reps only |
| cl.vertical-l-sit | Vertical L-Sit | hold(exercise: "vertical l-sit", seconds: 5) | any log: straddle l-sit | any log: vertical l-sit | any log: vertical l-sit + 20 reps toes to bar | PROXY: no seconds validation; variant/proxy reps only |
| hs.wall-plank | Wall Plank | hold(exercise: "wall plank", seconds: 30) | any log: wall plank | any log: wall plank + 3 reps handstand pushup | any log: wall plank + 20 reps handstand pushup | PROXY: no seconds validation; variant/proxy reps only |
| hs.wall-supported-oah | Wall Supported One-Arm Handstand | hold(exercise: "wall-supported one-arm handstand", seconds: 5) | any log: wall handstand | any log: wall-supported one-arm handstand + 5 reps handstand pushup | any log: wall-supported one-arm handstand + 3 reps press to handstand | PROXY: no seconds validation; variant/proxy reps only |
