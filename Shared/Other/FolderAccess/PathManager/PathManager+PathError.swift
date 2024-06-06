//
//  PathManager+PathError.swift
//  
//
//  Created by Julian Kahnert on 17.11.20.
//

extension PathManager {
    public enum PathError: Error {
        case archiveNotSelected
        case iCloudDriveNotFound
    }
}
