//
//  URL.swift
//  
//
//  Created by Julian Kahnert on 03.01.21.
//

import Foundation

extension URL {
    public func securityScope<T>(closure: (URL) throws -> T) rethrows -> T {
        let didAccessSecurityScope = startAccessingSecurityScopedResource()
        defer {
            if didAccessSecurityScope {
                stopAccessingSecurityScopedResource()
            }
        }
        return try closure(self)
    }
}
