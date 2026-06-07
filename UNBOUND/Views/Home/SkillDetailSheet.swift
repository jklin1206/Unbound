import SwiftUI

enum SkillDetailSheet: String, Identifiable {
    case session
    case quickLog
    case trainChooser

    var id: String { rawValue }
}
