# UNBOUND — Final Swift MVP Prompt

Paste this into Cursor with Claude for Swift/SwiftUI output. 3-day MVP.

---

```
Build an iOS app called UNBOUND — a body transformation tracker with brutal anime-flavored scan verdicts and gym-native gamification. SwiftUI + iOS 17+. 3-day MVP.

=====================================
CORE CONCEPT
=====================================

User takes a 3-photo body scan. AI matches them to a body archetype (BRUTE / UNIT / LEAN-CUT / CARVED / V-TAPER). Delivers a brutal verdict in the archetype's voice ("23% · you are currently food"). Unlocks a personalized 12-week training protocol split into 3 Arcs. Gamified with streaks, Gains (XP), and badges. Rescans monthly to measure real body change. Share cards are the viral growth engine.

NOT a quest game. NOT a Solo Leveling clone. A transformation tracker with a brutal scan verdict as the viral hook and gym-native gamification on top.

The name UNBOUND references Toji Fushiguro's Heavenly Restriction from JJK — a character who broke free from supernatural limitations to achieve peak physical form through pure body alone. Users are "unbinding" from their current limits. Insiders get the reference. Outsiders read "break free."

TAGLINE: "Break the restriction."

=====================================
TARGET USER
=====================================

Male, 16-28. Anime fan. Skinny or skinny-fat. Often never trained consistently. Motivated by Toji, Zoro, Sung Jin-Woo, Mackenyu-as-Zoro. Intimidated by traditional fitness apps. Wants measured transformation, not daily quest grinding.

=====================================
LANGUAGE RULES — do not violate
=====================================

USE:
- Archetype (BRUTE, UNIT, LEAN-CUT, CARVED, V-TAPER)
- Rank (E, D, C, B, A, S — starting-point labels)
- Gains (the XP currency — gym-native, original)
- Streak (session consistency days)
- Badge (milestone achievements)
- Session (daily workout — never "quest")
- Protocol / Program / Arc (12 weeks = 3 Arcs of 4 weeks)
- Scan / Rescan
- Verdict (scan result)
- Unbound / Unbind (the transformation state — used sparingly)

BANNED — do not use anywhere in-app:
- Quest / Daily quest / Daily mission
- Hunter / Warrior / Player
- System (as a persona)
- Ascension / Ascend
- Party / Guild / Squad
- Dungeon / Boss fight
- Level up (as event — use "rank changed")
- Anime character names in UI (Toji, Zoro, Jinwoo, Levi, Gojo)
  Character names appear ONLY as verdict quote voices on the scan result screen and share cards.

=====================================
DESIGN SYSTEM — "HOLLOW"
=====================================

Aesthetic: Brutalist Japanese minimalism. 95% monochrome. Single cursed violet accent that appears only at moments of impact. Yohji Yamamoto x Acronym x Hollow Purple. Severe, cold, confident.

Colors:
- Background: #050505 (pure near-black)
- Surface: #121212 (cards, modals)
- Text primary: #F5F5F4 (warm bone white)
- Text secondary: #737373
- Text tertiary: #404040
- Border: #262626
- Primary accent: #7C3AED (cursed violet — restrained, rare)
- Impact violet: #A855F7 (rank changes, badge unlocks only)
- Alert: #B91C1C (critical warnings only)

Violet usage rule (non-negotiable):
Violet is NOT default. It appears ONLY at:
1. Button press borders (default #262626 → #7C3AED on press)
2. Input focus states
3. Match % number on scan result
4. Gains balance + streak count on dashboard
5. Rank badge outline
6. Single scan line sweep during scan process
7. Rank-up bloom (uses impact violet #A855F7)
8. Archetype selection glow
EVERYWHERE ELSE: monochrome. When in doubt, remove violet, don't add it.

Typography:
- Display: PP Neue Montreal Bold (or Inter Tight ExtraBold as free alternative via Google Fonts)
- Body: Inter
- Numbers / stats: Geist Mono (or IBM Plex Mono)
- NO serif fonts anywhere

SwiftUI Components:
- Cards: RoundedRectangle, surface #121212, 1px border #262626. On press: border becomes #7C3AED + 6px violet shadow at 25% opacity.
- Buttons: transparent bg + 1px border #262626 + bone-white text. On press: border becomes violet + soft violet outer shadow.
- Rank badge: custom hexagon Shape, 2px violet stroke, rank letter centered in Geist Mono bone white.
- Progress bar: HStack of segmented Rectangles. Bone white default. Active earned segments glow violet.
- Scan lines: single 1px violet horizontal line, 0.4s sweep duration.
- Haptics: UIImpactFeedbackGenerator(.heavy) on major moments.

Animation principles:
- CUTS not fades. Max transition duration 0.15s.
- Rank-up: 600ms soft violet gradient wash from center, then fade. Crisp new rank letter.
- Scan reveal: black → violet blade sweep → content appears via crisp replace.
- No glows on idle state. Violet glow only on active/pressed.
- No gradients except one subtle vertical fade on hero screens (#121212 → #050505).
- Restraint > flourish. Always.

=====================================
ONBOARDING — 30 SCREENS
=====================================

Screen 1 — Splash
- Black bg (#050505)
- "UNBOUND" logo in PP Neue Montreal bone white, centered
- Tagline beneath: "Break the restriction."
- "BEGIN" button (transparent + violet border on press)

Screen 2 — Social proof counter
- "Join 12,847 others breaking their restriction."
- Animated count-up with .animation(.easeOut)

Screen 3 — Value prop
- "Most apps guess. UNBOUND scans."
- Side-by-side phone mockup comparison visual

Screen 4 — Pick archetype
- LazyVGrid of 5 archetype cards with silhouette illustrations:
  - BRUTE · power + lean
  - UNIT · mass + density
  - LEAN-CUT · balanced athlete
  - CARVED · compact + shredded
  - V-TAPER · tall + shoulder-heavy
- Selected card: violet border glow, scaleEffect(1.03)

Screen 5 — Why this archetype
- Multi-select capsules: Discipline · Aesthetic · Strength · Confidence · Recognition

Screen 6 — Age (Slider 14-40)
Screen 7 — Gender (M / F / Prefer not to say)
Screen 8 — Height (cm/in toggle slider)
Screen 9 — Weight (kg/lb toggle slider)

Screen 10 — Current body type
- 3 body illustrations: Skinny / Skinny-fat / Already lifting

Screen 11 — Experience
- Never trained / Tried once / Used to train / Currently training

Screen 12 — Current training frequency
- 0 / 1-2 / 3-4 / 5+ days per week

Screen 13 — Target training frequency
- 3 / 4 / 5 / 6 days per week
- "This sets your protocol intensity."

Screen 14 — Equipment (multi-select)
- Full gym / Home weights / Bodyweight only / Resistance bands

Screen 15 — Biggest obstacle (multi-select)
- Don't know what to do / Can't stay consistent / Plateau / Time / Motivation

Screen 16 — Time per session
- 30 / 45 / 60 / 90+ min

Screen 17 — Diet quality (1-10 slider)
Screen 18 — Sleep quality (1-10 slider)
Screen 19 — Stress level (1-10 slider)

Screen 20 — What have you tried (multi-select)
- Other apps / Personal trainer / YouTube / Nothing / Online programs

Screen 21 — Commitment
- "On a scale of 1-10, how committed are you?"
- Slider, default at 8

Screen 22 — Name input
- "What do you go by?"
- Single text field

Screen 23 — Notification permission
- "Your protocol adapts based on daily check-ins."
- Native iOS permission request

Screen 24 — Processing #1
- "ANALYZING PROFILE..."
- Violet scan line sweep across screen
- Fake progress bar 0% → 34%
- 3 seconds

Screen 25 — Processing #2
- "CALIBRATING ARCHETYPE..."
- Progress 34% → 71%
- 3 seconds

Screen 26 — Processing #3
- "COMPILING PROTOCOL..."
- Progress 71% → 100%
- 3 seconds

Screen 27 — Profile summary
- "Based on your profile:"
- "Estimated rank: E"
- "Archetype direction: [user's pick]"
- "Scan required to finalize."

Screen 28 — Projected trajectory
- Line chart: projected rank progression E → B over 12 months
- "At your commitment level, you should reach Rank C by month 4."

Screen 29 — Social proof gallery
- 3 scrolling testimonials:
  - "Rank E to B in 6 months. Finally something that tracks real change." — Marcus, 19
  - "The scan showed me exactly what was holding me back." — David, 23
  - "I don't look like the same kid. 90 days in." — Jamal, 17

Screen 30 — Scan prep
- "Your body scan is next."
- "3 photos: front, side, back."
- "Well-lit room. Minimal clothing. 6 feet from camera."
- "BEGIN SCAN" button

=====================================
SCAN FLOW — 5 SCREENS
=====================================

Screen 31 — Front photo
- AVFoundation camera with body silhouette overlay guide
- Auto-capture when user aligns
- Haptic pulse on capture

Screen 32 — Side photo (same UX)
Screen 33 — Back photo (same UX)

Screen 34 — Photo review
- 3 thumbnails displayed
- "Submit for analysis" button

Screen 35 — Scan processing
- "RUNNING BIOMETRIC ANALYSIS..."
- Violet scan lines animate across photos
- Fake progress 0% → 100%
- 4-6 seconds
- v1: returns STUBBED hardcoded result based on user's picked archetype

=====================================
SCAN RESULT — THE VIRAL MOMENT (4 screens)
=====================================

Screen 36 — Anticipation
- Black screen (#050505)
- Single violet blade-line sweeps horizontally across
- "VERDICT INCOMING" in small bone text
- 2 second pause
- Tension builds

Screen 37 — THE DRAG (the viral screen)
- Full takeover, no chrome
- Archetype name slams in (PP Neue Montreal, huge, bone white): "BRUTE"
- Below, large in Geist Mono VIOLET (#7C3AED): "23%"
- Archetype-voiced quote beneath (varies per archetype):
  - BRUTE: "You are currently food."
  - UNIT: "Train with Mihawk. Come back in a year."
  - LEAN-CUT: "Insufficient. But not hopeless."
  - CARVED: "Tch. Clean this up."
  - V-TAPER: "Don't embarrass me."
- Subcopy small bone: "Your protocol will close the gap."
- HEAVY haptic impact (.heavy) on reveal
- Two buttons: "Share verdict" + "Continue"

Screen 38 — Diagnostic
- Radar chart (Swift Charts framework) — 8 muscle groups scored (0-100)
- "Strengths: arms, core" (2 highlighted)
- "Focus areas: back, shoulders, chest" (3 highlighted in violet tint)

Screen 39 — Protocol reveal
- "YOUR PROTOCOL"
- "12 weeks · 3 Arcs · 4 sessions per week"
- Arc names:
  - Arc 1: Foundation (weeks 1-4)
  - Arc 2: Growth (weeks 5-8)
  - Arc 3: Power (weeks 9-12)
- Week 1 preview card visible
- "Unlock full protocol" → triggers PAYWALL

=====================================
SHARE CARD (auto-generated from Screen 37)
=====================================

Instagram Story size (1080 × 1920). Generated via ImageRenderer (iOS 16+).

- Background: black #050505
- Subtle violet gradient wash behind silhouette
- Abstract stylized archetype silhouette (NOT actual anime character art)
- Header: "[ARCHETYPE] VERDICT" in PP Neue Montreal
- Match % in violet Geist Mono, huge
- Quote line in bone
- Signature thin violet line detail at top
- "UNBOUND · break the restriction → unbound.app" at bottom
- UNBOUND logo in bone, bottom right

=====================================
PAYWALL — Screen 40
=====================================

- Header: "Close the gap."
- Value bullets (bone text, small violet dot markers):
  • 12-week protocol personalized to your scan
  • Monthly rescans + real rank updates
  • Daily Gains + streak tracking
  • Full archetype training library
- Pricing cards (side by side):
  • Weekly: $9.99/week (highlighted — "Most flexible")
  • Annual: $49.99/year (small violet tag: "SAVE 80%")
- 7-day free trial CTA button
- Small text: "Cancel anytime. Billing starts after trial."

=====================================
POST-PAYWALL — DASHBOARD + PROTOCOL
=====================================

Screen 41 — Dashboard (home)
- Header small muted: "Training toward BRUTE"
- Rank badge (hex violet outline): "E"
- Gains balance in Geist Mono violet: "47"
- Streak in violet: "3-day streak 🔥"
- Today card: "Wednesday · Back + Core · 52 min" with "Start session" button
- Next scan countdown: "Next scan in 14 days" (muted)
- TabView bottom: Home · Protocol · Timeline · Me

Screen 42 — Protocol view
- "Arc 1: Foundation — Week 2 of 4"
- 4-week calendar grid, today highlighted with violet border
- Each day: DisclosureGroup → exercise list (name, sets, reps, target weight)
- Rest days marked explicitly

Screen 43 — Today's session
- List of exercises with sets/reps/target weight in Geist Mono
- Per exercise: "Log set" button (stubbed local only in v1 — UserDefaults)
- "Complete session" at bottom → triggers:
  • Gains +30 animation (violet number rises)
  • Streak +1 update
  • Heavy haptic pulse
  • Returns to dashboard with updated state

=====================================
GAMIFICATION SYSTEM
=====================================

STREAKS
- Session streak = consecutive days user completed a scheduled session
- 1 rest day forgiveness per week (so 1 skip doesn't kill streak)
- Displayed on dashboard: flame icon + count
- Streak breaks = silent reset. No punishment UI. No guilt.

GAINS (XP equivalent, original naming)
- Earned from:
  • Complete scheduled session: +30 Gains
  • Hit target weight/reps on exercise: +10 Gains each
  • Complete full week (all sessions): +100 Gains bonus
  • Complete a rescan: +500 Gains
- Future use: cosmetic unlocks (scan card themes, wallpapers) — defer spending to v1.1
- Displayed: small number in Geist Mono violet on dashboard

BADGES
- Milestone achievements:
  • "First Scan" — complete first body scan
  • "7 Day" — 7-day streak
  • "30 Day" — 30-day streak
  • "First Rescan" — complete monthly rescan
  • "Rank Up" — any rank transition (E → D, etc.)
  • "Arc Complete" — finish 4-week arc
  • "Consistency" — 90%+ session completion over 30 days
- Earning triggers: impact violet bloom haptic moment
- Display: badge gallery in Me tab (defer visual display to v1.1, just persist data in v1)

RANKS (E → S)
- E, D, C, B, A, S
- Determined by scan result ONLY — not earned through activity
- Rank can go up or stay same on rescan (never down — no decay)
- Rank displayed as simple hexagon badge with letter on dashboard

=====================================
COPY VOICE RULES
=====================================

- Second person, declarative, present tense
- Clinical when showing data. Brutal when delivering verdict.
- Archetype-voiced quotes ONLY on scan reveal (Screen 37) and share cards
- Everywhere else: neutral, measured, confident
- Never cheerleading ("Great job!"). Never gamified hype ("XP earned!").
- No emoji in-app except streak flame 🔥
- All numbers displayed in Geist Mono for "readout" feel

Correct:
✅ "Session logged. +30 Gains. Streak: 4 days."
✅ "Rank improved: E → D."
✅ "Scan scheduled Apr 30."
✅ "Arc 1 complete. Arc 2 begins."

Incorrect:
❌ "Great job! You leveled up!"
❌ "Quest complete! 🎉"
❌ "Welcome, hunter!"
❌ "Your ascension begins!"

=====================================
TECH STACK
=====================================

- Swift 5.9+
- SwiftUI (iOS 17+ minimum target)
- NavigationStack for routing
- Swift Charts for radar chart + trajectory line chart
- AVFoundation for camera capture
- UserDefaults or SwiftData for v1 local persistence
- Firebase iOS SDK:
  - Auth (Apple Sign-In + anonymous)
  - Firestore (user profile + scan results)
  - Storage (scan photos)
- RevenueCat iOS SDK for subscriptions
- Superwall iOS SDK for paywall variant testing
- ImageRenderer (iOS 16+) for share card generation
- UIImpactFeedbackGenerator for haptics

Scan AI: STUBBED in v1 — return hardcoded result object keyed to user's picked archetype. Real Claude/GPT-4 Vision integration ships in v1.1.

Architecture: MVVM with @Observable view models (iOS 17). Service layer (ScanService, UserService, PaywallService, GamificationService) injected via SwiftUI environment.

=====================================
BUILD PRIORITY — 3 DAY MVP
=====================================

DAY 1 — Foundation + Onboarding
- Design system: color tokens, typography, reusable components (UnboundCard, UnboundButton, RankBadge, ScanLineSweep, ProgressBar)
- Navigation scaffold with NavigationStack
- All 30 onboarding screens (Screens 1-30)
- User profile model + UserDefaults persistence
- Onboarding state management

DAY 2 — Scan + Verdict + Paywall
- Camera flow with AVFoundation (Screens 31-35)
- Scan result verdict reveal with animations (Screens 36-39)
- Share card generator via ImageRenderer
- Paywall integration with RevenueCat + Superwall (Screen 40)
- Firebase Auth setup (Apple Sign-In)

DAY 3 — Dashboard + Protocol + Polish
- Dashboard home screen (Screen 41)
- Protocol view (Screen 42)
- Today's session view (Screen 43)
- Streak + Gains + Badge persistence and display
- Haptics pass across entire app (every major interaction)
- Animation pass (scan sweep, verdict reveal, rank-up bloom, page transitions)
- Final polish, edge cases, test on device

=====================================
DEFER TO v1.1 (ship within 2 weeks after launch)
=====================================

- Real AI scan analysis (Claude Vision API or GPT-4 Vision)
- PT Agent conversational chat
- Rescan flow (full monthly rescan with before/after comparison)
- Progress timeline view with before/after photo slider
- Gains spending (cosmetic scan card themes, wallpapers)
- Full exercise library with video demonstrations
- Apple Health sync
- Push notification scheduling
- Badge gallery display in Me tab
- Community / social sharing beyond basic share card
- Workout logging persistence beyond UserDefaults

=====================================
CRITICAL CONSTRAINTS
=====================================

1. Onboarding total time: 3-5 minutes. Substantial but not tedious.
2. Scan flow: under 90 seconds from first photo to submission.
3. Scan verdict (Screen 37) MUST fire BEFORE paywall — users see the roast first, then pay.
4. All 3 fake processing screens (24-26) build psychological commitment — do not skip them.
5. Share card = the growth engine. Treat as a hero feature, not afterthought.
6. NO "quest" word. NO "hunter" word. Anywhere. Ever.
7. Archetype names in-app: BRUTE / UNIT / LEAN-CUT / CARVED / V-TAPER only.
8. Character names (Toji, Zoro, etc.) appear ONLY as verdict quote voices on Screen 37.
9. Match % is the viral meme, framed as character judgment, NOT clinical assessment.
10. Violet accent used SPARINGLY per the Violet Usage Rule — when in doubt, remove.
11. Haptics HEAVY on major moments (scan, verdict, rank change, badge, session complete).
12. Animations are CUTS not fades. Max 0.15s transitions. Sharp, not soft.
13. Restraint is the design language. When in doubt, remove, don't add.

=====================================
REFERENCE INSPIRATIONS (for design direction, not copying)
=====================================

- Umax (brutal quantification + viral share cards)
- Cal AI (30-screen onboarding funnel psychology)
- Linear app (monochrome + violet accent language)
- Acronym / A-COLD-WALL* (technical brutalist aesthetic)
- Yohji Yamamoto (severe Japanese monochrome fashion)
- JJK Hollow Purple (cursed violet on black visual)
- Peloton (subscription + paywall framing)
- Whoop / Oura (clean measured data, no game mechanics)
- Supreme (black + bold type brand energy)

=====================================
FINAL NOTE TO BUILDER
=====================================

UNBOUND is a body transformation tracker dressed in severe Japanese brutalism with a viral anime-voiced verdict as the share hook. The name references Toji Fushiguro's Heavenly Restriction — the concept that giving up one power unlocks peak physical form. Users are unbinding from their limits.

The app should feel like what happens when Acronym and Gojo build a body scanner — measured, cold, devastating, confident. Every pixel is functional. Every haptic is heavy. Every screen is either necessary or removed.

The verdict is brutal. The dashboard is clean. The protocol is honest. The transformation is measured.

Build the 3-day MVP tight. Ship to TestFlight day 4. App Store day 7. TikTok content starts TODAY, not after ship.

Break the restriction.
```
