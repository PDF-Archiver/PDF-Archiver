//
//  FolderProviderError.swift
//  
//
//  Created by Julian Kahnert on 22.08.20.
//

import Foundation

/// Errors which can occur while handling a document.
///
/// - description: A error in the description.
/// - tags: A error in the document tags.
/// - renameFailedFileAlreadyExists: A document with this name already exists in the archive.
public enum FolderProviderError: Error {
    case date
    case description
    case tags
    case renameFailedFileAlreadyExists
}

extension FolderProviderError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .date:
            return NSLocalizedString("document_error_description__date_missing", comment: "No date could be found, e.g. while renaming the document.")
        case .description:
            return NSLocalizedString("document_error_description__description_missing", comment: "No description could be found, e.g. while renaming the document.")
        case .tags:
            return NSLocalizedString("document_error_description__tags_missing", comment: "No tags could be found, e.g. while renaming the document.")
        case .renameFailedFileAlreadyExists:
            return NSLocalizedString("document_error_description__rename_failed_file_already_exists", comment: "Rename failed.")
        }
    }

    public var failureReason: String? {
        switch self {
        case .date:
            return NSLocalizedString("document_failure_reason__date_missing", comment: "No date could be found, e.g. while renaming the document.")
        case .description:
            return NSLocalizedString("document_failure_reason__description_missing", comment: "No description could be found, e.g. while renaming the document.")
        case .tags:
            return NSLocalizedString("document_failure_reason__tags_missing", comment: "No tags could be found, e.g. while renaming the document.")
        case .renameFailedFileAlreadyExists:
            return NSLocalizedString("document_failure_reason__rename_failed_file_already_exists", comment: "Rename failed.")
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .date:
            return NSLocalizedString("document_recovery_suggestion__date_missing", comment: "No date could be found, e.g. while renaming the document.")
        case .description:
            return NSLocalizedString("document_recovery_suggestion__description_missing", comment: "No description could be found, e.g. while renaming the document.")
        case .tags:
            return NSLocalizedString("document_recovery_suggestion__tags_missing", comment: "No tags could be found, e.g. while renaming the document.")
        case .renameFailedFileAlreadyExists:
            return NSLocalizedString("document_recovery_suggestion__rename_failed_file_already_exists", comment: "Rename failed - file already exists.")
        }
    }
}
