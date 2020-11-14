//
//  Document+TaggingStatus.swift
//  
//
//  Created by Julian Kahnert on 15.08.20.
//

extension Document {
    /// Tagging status of a document.
    ///
    /// - tagged: Document is already tagged.
    /// - untagged: Document that is not tagged.
    public enum TaggingStatus: String, Comparable, Codable {
        case tagged
        case untagged

        public static func < (lhs: TaggingStatus, rhs: TaggingStatus) -> Bool {
            return lhs == .untagged && rhs == .tagged
        }
    }
}
