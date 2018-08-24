//
//  StringExtensions.swift
//  PDFArchiveViewer
//
//  Created by Julian Kahnert on 23.08.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation

extension String {

    func capturedGroups(withRegex pattern: String) -> [String]? {
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
                                    range: NSRange(location: 0, length: self.count))

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
}
