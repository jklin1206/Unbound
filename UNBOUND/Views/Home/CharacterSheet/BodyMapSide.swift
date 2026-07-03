import SwiftUI

// MARK: - BodyMapSide
//
// Shared side enum for the app's body-map figures (heatmap, exercise target
// muscles, rank library target body). Each consumer defines its own region
// specs / paths against this shared side.

enum BodyMapSide: Sendable { case front, back }
