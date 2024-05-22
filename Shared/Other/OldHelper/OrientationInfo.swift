//
//  OrientationInfo.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 25.02.20.
//  Copyright © 2020 Julian Kahnert. All rights reserved.
//
// Source: https://forums.developer.apple.com/thread/126878

import SwiftUI

public final class OrientationInfo: ObservableObject {
    public enum Orientation {
        case portrait
        case landscape
    }

    @Published public var orientation: Orientation

    private var _observer: NSObjectProtocol?

    public init() {
        #if canImport(UIKit)
        // fairly arbitrary starting value for 'flat' orientations
        if UIDevice.current.orientation.isLandscape {
            self.orientation = .landscape
        } else {
            self.orientation = .portrait
        }

        // unowned self because we unregister before self becomes invalid
        _observer = NotificationCenter.default.addObserver(forName: UIDevice.orientationDidChangeNotification, object: nil, queue: nil) { [unowned self] note in
            guard let device = note.object as? UIDevice else {
                return
            }
            if device.orientation.isPortrait {
                self.orientation = .portrait
            } else if device.orientation.isLandscape {
                self.orientation = .landscape
            }
        }
        #else
        self.orientation = .landscape
        #endif
    }

    deinit {
        if let observer = _observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
