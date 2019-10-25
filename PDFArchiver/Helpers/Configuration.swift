//
//  Configuration.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 20.10.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

import Foundation

enum Configuration {
    enum ConfigError: Error {
        case missingKey, invalidValue
    }

    static func value<T>(for key: String) throws -> T where T: LosslessStringConvertible {
        guard let object = Bundle.main.object(forInfoDictionaryKey: key) else {
            throw ConfigError.missingKey
        }

        switch object {
        case let value as T:
            return value
        case let string as String:
            guard let value = T(string) else { throw ConfigError.invalidValue }
            return value
        default:
            throw ConfigError.invalidValue
        }
    }
}
