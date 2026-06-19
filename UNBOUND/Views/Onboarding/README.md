# Views/Onboarding

The 33-step onboarding flow: `OnboardingContainerView` routes steps off `OnboardingFlowViewModel.currentStep` through the arc answers → scan → analyzing → verdict → trajectory → social proof → paywall → home. The individual step screens live in `Steps/` (Step_Arc01…Step29 etc.); `Components/` holds `Components/LifestyleSignalAsset.swift` (diet/sleep/stress glyph assets).

## Files (this level)

| File | What it is |
|---|---|
| `OnboardingContainerView.swift` | Routes the whole flow based on `flow.currentStep`; `ServiceContainer` injects user + camera services. |
| `OnboardingAtmosphere.swift` | Persistent ambient visual layer under every step's content; `intensity` dial scales it up as the flow progresses. |
| `OnboardingAssetGlyph.swift` | `OnboardingAssetGlyph` + shape enum — reusable glyph rendering for steps. |
| `OnboardingWelcomeView.swift` | `OnboardingWelcomeView` — welcome screen. |
| `OnboardingHowItWorksView.swift` | `OnboardingHowItWorksView` — how-it-works explainer. |
| `OnboardingConversionStepResultsSnapshot.swift` | `Step_ResultsSnapshot` — inserted conversion step. |
| `OnboardingConversionStepPlanReady.swift` | `Step_PlanReady` — inserted conversion step. |
| `RPEOnboardingStep.swift` | Product-loop demo step: log a real set with the production `ExerciseLogCard`, rate effort, see progress move. |
| `Steps/` | All numbered/arc step screens (Step05_Motivation … Step29_SocialProof, Step_Arc*, Step_Scan*, Step_Verdict*, Step_Paywall, chapter interstitials). |
| `Components/` | `Components/LifestyleSignalAsset.swift` — diet/sleep/stress signal asset view. |

## Where to find X

- **Step ordering / which view shows for a step** → `OnboardingContainerView.swift` (routing) + `UNBOUND/ViewModels/Onboarding/OnboardingStep.swift` (the step enum).
- **Flow state, navigation, validation** → `UNBOUND/ViewModels/Onboarding/OnboardingFlowViewModel*.swift`.
- **A specific question/cinematic screen** → `Steps/Step_*.swift` by name.
- **The shared animated background behind steps** → `OnboardingAtmosphere.swift`.
- **Paywall step** → `Steps/Step_Paywall.swift`.
