# Mobility Reference Asset Queue

Use this for UNBOUND mobility and stretch references. This adapts the `unbound-skill-assets` style lock for mobility: these are pose references, not skill-progress dossier sheets.

## Style Lock

Every image must preserve the recurring UNBOUND movement avatar:

- Anime/webtoon male-presenting athlete.
- Sharp messy black hair.
- Lean calisthenics build, not bulky.
- Low-detail face.
- Black sleeveless training top, black pants, black shoes.
- Wrist wraps.
- Cyan/teal rim light and subtle teal motion accent.
- Occasional orange/yellow arrow only when it clarifies movement.
- No violet or purple accents.
- Plain dark charcoal/black background.
- No app UI, squad logos, badges, crowns, menus, emblems, flags, extra people, or decorative branding.

## Format Standard

Mobility references should answer one question: "What position should my body be in?"

- Static stretch: one clean final-pose image named `mobility_reference_<id>`.
- Dynamic mobility drill: two clean images named `mobility_reference_<id>_start` and `mobility_reference_<id>_end`.
- Optional labels only: `START` and `END` for a two-image drill. Static stretches should not need labels.
- No four-panel sheets for mobility unless a movement is genuinely too complex for one/two poses.
- A user should understand the position in under one second without reading the cue.

## Single-Pose Prompt

```text
Create one clean webtoon/anime mobility reference image for the UNBOUND fitness app.

Use the existing UNBOUND movement avatar style: recurring anime/webtoon male-presenting athlete, sharp messy black hair, lean calisthenics build, low-detail face, black sleeveless training top, black pants, black shoes, wrist wraps, cyan/teal rim light, subtle teal accents. Do NOT use violet or purple accents.

Subject: [MOVEMENT] final stretch position.
Camera: [CAMERA ANGLE].
Pose: [FINAL POSITION DESCRIPTION].

Strict background rules: plain dark charcoal/black background only. No app navigation UI, no squad logos, no people in background, no profile icons, no crowns, no badges, no menu elements, no flags, no shields, no emblems, no decorative app branding, no extra text.

Show the full body and all important contact points: hands, knees, feet, wall/floor/couch contact if used. The stretch mechanics must be anatomically clear: [KEY BODY POSITION CUES]. Make it instructional, not cinematic. High-contrast webtoon training-manual style, not photorealistic.
```

## Start/End Prompt

```text
Create two separate webtoon/anime mobility reference images for the UNBOUND fitness app: START and END.

Use the existing UNBOUND movement avatar style: recurring anime/webtoon male-presenting athlete, sharp messy black hair, lean calisthenics build, low-detail face, black sleeveless training top, black pants, black shoes, wrist wraps, cyan/teal rim light, subtle teal accents. Do NOT use violet or purple accents.

Subject: [MOVEMENT] mobility drill.
Camera: [CAMERA ANGLE], same camera and same body direction in both images.

START pose: [START POSITION DESCRIPTION].
END pose: [END POSITION DESCRIPTION].

Strict background rules: plain dark charcoal/black background only. No app navigation UI, no squad logos, no people in background, no profile icons, no crowns, no badges, no menu elements, no flags, no shields, no emblems, no decorative app branding, no extra text beyond optional START or END labels.

Show the full body and all important contact points. The mechanic must be visually obvious: [KEY BODY POSITION CUES]. Use a small amber/cyan arrow only if it clarifies the path. High-contrast webtoon training-manual style, not photorealistic.
```

## Review Gate

Do not integrate an image unless it passes visual QA:

- Same avatar identity and outfit.
- Correct cyan/teal style, no purple.
- No UI or branding contamination.
- Full body visible unless the movement explicitly needs a close-up.
- Hands, knees, feet, spine, and floor/wall/couch contacts are anatomically possible.
- The selected camera angle teaches the stretch better than a generic front pose.
- The most important cue is visible in the image itself.
- Static stretches use one strong pose; dynamic drills use only start/end.

## Asset Names

Drop finished reviewed assets into `UNBOUND/Assets.xcassets/`:

- Single pose: `mobility_reference_<id>.imageset/mobility_reference_<id>.png`
- Start/end: `mobility_reference_<id>_start.imageset/mobility_reference_<id>_start.png`
- Start/end: `mobility_reference_<id>_end.imageset/mobility_reference_<id>_end.png`

The app reads these names from `MobilityReferenceLibrary`.

## Priority Queue

| Asset id | Movement | Format | Camera | Key visual cue |
| --- | --- | --- | --- | --- |
| `cat_cow` | Cat-Cow | Start/end | Side view | Tabletop spine rounded vs arched |
| `worlds_greatest_stretch` | World's Greatest Stretch | Start/end | Front three-quarter | Long lunge, elbow inside foot, torso rotation |
| `thread_the_needle` | Thread the Needle | Start/end | Top/front oblique | Arm threads under chest, shoulder rotates |
| `thoracic_rotation` | Thoracic Rotation | Start/end | Top/front oblique | Lower body pinned, rib cage opens |
| `hip_90_90_switch` | 90-90 Hip Switch | Start/end | Front three-quarter | Both knees at 90 degrees, hips rotate sides |
| `shoulder_cars` | Shoulder CARs | Start/end | Side view | Big pain-free shoulder circle, ribs down |
| `deep_squat_hold` | Deep Squat Hold | Single pose | Front three-quarter | Heels down, knees track toes, chest open |
| `hip_flexor_stretch` | Hip Flexor Stretch | Single pose | Side view | Rear glute on, pelvis tucked, long lunge |
| `couch_stretch` | Couch Stretch | Single pose | Side view | Back shin on wall/couch, ribs stacked |
| `hamstring_fold` | Hamstring Fold | Single pose | Side view | Hip hinge, soft knees, long spine |
| `figure_four` | Figure-4 Stretch | Single pose | Front three-quarter | Ankle crossed above knee, active foot |
| `pigeon_pose` | Pigeon Pose | Single pose | Side/front three-quarter | Front shin angled, back leg long, knee safe |
| `frog_stretch` | Frog Stretch | Single pose | Front three-quarter | Wide knees, shins parallel, hips shift back |
| `lat_prayer_stretch` | Lat Prayer Stretch | Single pose | Side three-quarter | Hips back, arms long, ribs down |
| `wall_pec_stretch` | Wall Pec Stretch | Single pose | Side three-quarter | Palm/forearm on wall, chest turns away |
| `wrist_rocks` | Wrist Rocks | Start/end | Side view | Palm contact, shoulders rock past wrists |
| `knee_to_wall_ankle` | Knee-to-Wall Ankle Rock | Start/end | Side view | Heel down, knee tracks over toes |
| `calf_pedal` | Calf Pedal | Start/end | Side view | Pike position, alternating heel press |
