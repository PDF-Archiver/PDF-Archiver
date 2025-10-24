//
//  Bool.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 22.05.24.
//

public extension Bool {
    var flipped: Self {
        get { !self }
        set { self = !newValue }
    }
}
