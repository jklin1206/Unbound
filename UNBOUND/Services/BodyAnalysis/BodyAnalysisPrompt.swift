import Foundation

/// Prompt for Body Analysis flavor copy.
/// Thin glue — the actual prompt lives in ScanPayoffFlavorService.
/// Use ScanPayoffFlavorService.composedPrompt(buildIdentityName:dominantAxis:) directly
/// from @MainActor contexts (it is @MainActor-isolated).
enum BodyAnalysisPrompt {
    // Intentionally empty — the old Gemini grading prompt has been removed.
    // Flavor copy generation is handled entirely by ScanPayoffFlavorService.
}
