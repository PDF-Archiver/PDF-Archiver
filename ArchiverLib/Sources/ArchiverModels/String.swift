//
//  String.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 09.07.25.
//

import Foundation

nonisolated public extension String {
    /// Slugify the string and separate each part.
    ///
    /// - Parameter separator: Character which will be used for the separation.
    /// - Returns: Cleaned string.
    func slugified(withSeparator separator: String = "-") -> String {
        // this function is inspired by:
        // https://github.com/malt03/SwiftString/blob/0aeb47cbfa77cf8552bbadf49360ef529fbb8c03/Sources/StringExtensions.swift#L194
        let slugCharacterSet = NSCharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789\(separator)")
        return replacing("ß", with: "ss")
            .replacing("Ä", with: "Ae")
            .replacing("Ö", with: "Oe")
            .replacing("Ü", with: "Ue")
            .replacing("ä", with: "ae")
            .replacing("ö", with: "oe")
            .replacing("ü", with: "ue")
            .folding(options: .diacriticInsensitive, locale: .current)
            .components(separatedBy: slugCharacterSet.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: separator)
            .replacing(/[^0-9a-zA-Z]+/, with: separator)
    }
}
