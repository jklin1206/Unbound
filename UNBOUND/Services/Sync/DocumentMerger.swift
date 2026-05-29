import Foundation

/// Pure field-level merge primitive for the sync spine. Lets two devices that
/// edited DIFFERENT top-level fields of the same document converge to the union
/// instead of one whole-document write clobbering the other (bug #5, LWW).
///
/// No I/O, no shared state — total over its inputs so it is trivially testable.
enum DocumentMerger {

    /// Returns `base` with ONLY the named top-level `fields` taken from `source`.
    ///
    /// - A listed field present in `source` overwrites `base`'s value.
    /// - A listed field absent in `source` is removed from the result
    ///   (the edit deleted that field).
    /// - Any field not listed keeps `base`'s value.
    ///
    /// If either side is not a JSON object, `source` is returned unchanged —
    /// there are no top-level fields to overlay onto.
    ///
    /// - Parameters:
    ///   - fields: top-level keys this edit is authoritative for.
    ///   - source: the document carrying the new field values.
    ///   - base:   the document to overlay onto.
    /// - Returns: the merged document.
    static func overlay(fields: [String], from source: JSONElement,
                        onto base: JSONElement) -> JSONElement {
        guard case .object(var result) = base,
              case .object(let src) = source else {
            return source
        }
        for field in fields {
            if let value = src[field] {
                result[field] = value
            } else {
                result.removeValue(forKey: field)
            }
        }
        return .object(result)
    }
}
