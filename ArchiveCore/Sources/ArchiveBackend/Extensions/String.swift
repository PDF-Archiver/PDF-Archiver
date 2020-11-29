//
//  String.swift
//  
//
//  Created by Julian Kahnert on 25.10.19.
//

import Foundation

extension String {
    /// Slugify the string and seperate each part.
    ///
    /// - Parameter separator: Character which will be used for the seperation.
    /// - Returns: Cleaned string.
    public func slugified(withSeparator separator: String = "-") -> String {
        // this function is inspired by:
        // https://github.com/malt03/SwiftString/blob/0aeb47cbfa77cf8552bbadf49360ef529fbb8c03/Sources/StringExtensions.swift#L194
        let slugCharacterSet = NSCharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789\(separator)")
        return replacingOccurrences(of: "ß", with: "ss")
            .replacingOccurrences(of: "Ä", with: "Ae")
            .replacingOccurrences(of: "Ö", with: "Oe")
            .replacingOccurrences(of: "Ü", with: "Ue")
            .replacingOccurrences(of: "ä", with: "ae")
            .replacingOccurrences(of: "ö", with: "oe")
            .replacingOccurrences(of: "ü", with: "ue")
            .folding(options: .diacriticInsensitive, locale: .current)
            .components(separatedBy: slugCharacterSet.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: separator)
            .replacingOccurrences(of: "[^0-9a-zA-Z]+", with: separator, options: .regularExpression, range: nil)
    }

    /// Find groups by a given regular expression.
    ///
    /// - Parameter pattern: regular expression which captures a group
    /// - Returns: Array of found groups
    public func capturedGroups(withRegex pattern: String) -> [String]? {
        // this function is inspired by:
        // https://gist.github.com/unshapedesign/1b95f78d7f74241f706f346aed5384ff
        var regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern,
                                            options: [])
        } catch {
            return nil
        }
        let matches = regex.matches(in: self,
                                    options: [],
                                    range: NSRange(location: 0, length: count))

        guard let match = matches.first else { return nil }

        let lastRangeIndex = match.numberOfRanges - 1
        guard lastRangeIndex >= 1 else { return nil }

        var results = [String]()
        for idx in 1...lastRangeIndex {
            let capturedGroupIndex = match.range(at: idx)
            let matchedString = (self as NSString).substring(with: capturedGroupIndex)
            results.append(matchedString)
        }
        return results
    }

    public var isNumeric: Bool {
        CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: self))
    }

    public var localized: String {
        return NSLocalizedString(self, comment: "")
    }

//    /// Returns a capitalized version, e.g. "Blue Pullover".
//    public var capitalized: String {
//        self
//            .split { [" ", "-"].contains($0) }
//            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
//            .joined(separator: " ")
//    }
}
