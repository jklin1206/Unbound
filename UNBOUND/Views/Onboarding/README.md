# Views/Onboarding

Full 30-step UNBOUND onboarding flow: container router, atmospheric visuals, individual question/cinematic steps, and reusable primitives. The `Steps/` subfolder holds ~40 step views (arc cinematics, data-collection questions, verdict, paywall, and processing) driven by `OnboardingFlowViewModel`.

| File | Purpose |
|------|---------|
| `OnboardingContainerView.swift` | Root router: initializes `OnboardingFlowViewModel`, dispatches each step to its view |
| `OnboardingWelcomeView.swift` | Pre-flow welcome screen shown before `OnboardingFlowViewModel` is created |
| `OnboardingHowItWorksView.swift` | "How It Works" explainer shown as an interstitial step |
| `OnboardingStepViews.swift` | `Step_ResultsSnapshot` — inline conversion step showing the user's profile summary mid-flow |
| `OnboardingAtmosphere.swift` | Persistent visual atmosphere layer shared across all steps (scales with intensity param) |
| `OnboardingAssetGlyph.swift` | Chamfered/hex/circle icon glyph wrapper used for step illustrations |
| `RPEOnboardingStep.swift` | Product-loop demo step: logs a real set with `ExerciseLogCard` to show RPE in context |
| `Components/LifestyleSignalAsset.swift` | Reusable asset+label composite for diet/sleep/stress signal steps |

## Where to find X

| Task | File |
|------|------|
| Change step routing or flow order | `OnboardingContainerView.swift` + `ViewModels/Onboarding/OnboardingStep.swift` |
| Edit a specific question or cinematic step | `Steps/<StepName>.swift` |
| Adjust the background atmosphere visuals | `OnboardingAtmosphere.swift` |
| Modify the RPE product demo step | `RPEOnboardingStep.swift` |
| Change the icon glyph style used in step illustrations | `OnboardingAssetGlyph.swift` |
