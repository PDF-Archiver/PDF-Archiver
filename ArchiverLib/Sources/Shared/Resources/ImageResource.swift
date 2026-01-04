//
//  ImageResource.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 16.07.25.
//

import DeveloperToolsSupport
import Foundation

public extension ImageResource {
    static var logoAsset: ImageResource {
        ImageResource(name: "Logo", bundle: #bundle)
    }

    static var scanAsset: ImageResource {
        ImageResource(name: "scan", bundle: #bundle)
    }

    static var tag1Asset: ImageResource {
        ImageResource(name: "tag1", bundle: #bundle)
    }

    static var findAsset: ImageResource {
        ImageResource(name: "find", bundle: #bundle)
    }

    static var piggyBankAsset: ImageResource {
        ImageResource(name: "piggyBank", bundle: #bundle)
    }

    static var startAsset: ImageResource {
        ImageResource(name: "start", bundle: #bundle)
    }
}
