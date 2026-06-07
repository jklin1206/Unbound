import Foundation
@testable import UNBOUND

extension Calendar {
    static var fixedGMT: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
