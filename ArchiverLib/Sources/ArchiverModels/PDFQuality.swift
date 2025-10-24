//
//  PDFQuality.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 22.08.25.
//

public enum PDFQuality: Float, CaseIterable, Sendable, Codable {
    case lossless = 1.0
    case good = 0.75
    case normal = 0.5
    case small = 0.25
}
