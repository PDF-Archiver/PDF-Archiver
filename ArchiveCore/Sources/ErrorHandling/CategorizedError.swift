//
//  CategorizedError.swift
//  
//
//  Created by Julian Kahnert on 30.10.20.
//
// Source: https://www.swiftbysundell.com/articles/propagating-user-facing-errors-in-swift/

protocol CategorizedError: Error {
    var category: ErrorCategory { get }
}
