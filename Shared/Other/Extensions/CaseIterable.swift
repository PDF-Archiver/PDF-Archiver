//
//  CaseIterable.swift
//  
//
//  Created by Julian Kahnert on 18.11.20.
//

extension CaseIterable where AllCases.Element: Equatable {
    static func toIndex(_ element: Self) -> Int? {
        guard let index = Self.allCases.firstIndex(of: element) else { return nil }
        return index as? Int
    }
}
