//
//  DocumentTypealias.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 27.07.26.
//

import ArchiverModels

/// Resolves the ambiguity with `SwiftUI.Document` (new in the 26.6 SDK) in
/// files that import both modules.
public typealias Document = ArchiverModels.Document
