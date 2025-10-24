//
//  Array.swift
//
//
//  Created by Julian Kahnert on 22.08.20.
//

import Foundation

extension Array where Array.Element == URL {
    func getUniqueParents() -> [URL] {
        let newFolders = self.filter { currentFolder in
            let hasParent = self.contains { observedFolder in
                observedFolder != currentFolder &&
                    currentFolder.path.starts(with: observedFolder.path)
            }
            return !hasParent
        }
        return newFolders
    }
}
