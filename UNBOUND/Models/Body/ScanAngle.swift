import Foundation

enum ScanAngle: String, Codable, CaseIterable {
    case front, side, back

    var instruction: String {
        switch self {
        case .front: return "Stand facing the camera with arms slightly away from your sides."
        case .side: return "Stand sideways to the camera with arms slightly away from your sides."
        case .back: return "Stand with your back to the camera with arms slightly away from your sides."
        }
    }

    var order: Int {
        switch self {
        case .front: return 1
        case .side: return 2
        case .back: return 3
        }
    }
}
