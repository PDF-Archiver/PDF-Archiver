//
//  DocumentProtocol.swift
//  PDF Archiver
//
//  Created by Julian Kahnert on 26.01.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation

protocol DocumentProtocol {
    
    func getDocumentDate() -> Date
    func getDocumentDescription() -> String
}
