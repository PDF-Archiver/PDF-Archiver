//
//  ErrorCategory.swift
//  
//
//  Created by Julian Kahnert on 30.10.20.
//
// Source: https://www.swiftbysundell.com/articles/propagating-user-facing-errors-in-swift/

enum ErrorCategory {
    case nonRetryable
    case retryable
//    case requiresLogout
}
