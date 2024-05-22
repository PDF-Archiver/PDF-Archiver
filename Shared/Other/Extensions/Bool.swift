//
//  Bool.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 22.05.24.
//

extension Bool {
    var flipped: Self {
        get { !self }
        set { self = !newValue }
    }
}
