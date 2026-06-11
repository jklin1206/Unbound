import Foundation

extension FileManager {
    /// The app's Documents directory. On iOS this always exists; the
    /// temporary-directory fallback keeps a missing search path from
    /// crashing at launch (degrades to non-persistent storage instead).
    var documentsDirectory: URL {
        urls(for: .documentDirectory, in: .userDomainMask).first ?? temporaryDirectory
    }
}
