//
//  ImageResource.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 16.07.25.
//

import DeveloperToolsSupport

public extension ImageResource {
    static var logoAsset: ImageResource {
        ImageResource(name: "Logo", bundle: .module)
    }

    static var scanAsset: ImageResource {
        ImageResource(name: "scan", bundle: .module)
    }

    static var tag1Asset: ImageResource {
        ImageResource(name: "tag1", bundle: .module)
    }

    static var findAsset: ImageResource {
        ImageResource(name: "find", bundle: .module)
    }

    static var piggyBankAsset: ImageResource {
        ImageResource(name: "piggyBank", bundle: .module)
    }

    static var startAsset: ImageResource {
        ImageResource(name: "start", bundle: .module)
    }
}
