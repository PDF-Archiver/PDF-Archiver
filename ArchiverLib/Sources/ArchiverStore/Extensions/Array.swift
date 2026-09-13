//
//  Array.swift
//
//
//  Created by Julian Kahnert on 22.08.20.
//

import Foundation

extension Array where Array.Element == URL {
    func getUniqueParents() -> [URL] {
        return self.filter { currentFolder in
            let hasParent = self.contains { observedFolder in
                // Compare with a trailing separator so a sibling folder `Archive2` is not treated
                // as a child of `Archive`.
                observedFolder != currentFolder &&
                    (currentFolder.path + "/").starts(with: observedFolder.path + "/")
            }
            return !hasParent
        }
    }
}
