//
//  DocumentCameraViewController.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 02.11.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//

#if !os(macOS)
import SwiftUI
import VisionKit

extension VNDocumentCameraScan: @unchecked @retroactive Sendable {}
#endif
