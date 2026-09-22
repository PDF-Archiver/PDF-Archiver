//
//  ArchiveStore+Error.swift
//  
//
//  Created by Julian Kahnert on 22.08.20.
//

import ArchiverModels

extension ArchiveStore {
    enum Error: Swift.Error {
        case providerNotFound
    }
}

extension ArchiveStore.Error: LogSafeError {
    var logDescription: String { "\(self)" }
}
