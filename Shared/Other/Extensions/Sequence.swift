//
//  Sequence.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 26.03.24.
//

extension Sequence where Element: Hashable {
    var histogram: [Element: Int] {
        return self.reduce(into: [:]) { counts, elem in counts[elem, default: 0] += 1 }
    }
}
