//
//  Bundle.swift
//  
//
//  Created by Julian Kahnert on 02.12.20.
//

import Foundation

extension Bundle {
    static let longTextPDFUrl = URL(fileURLWithPath: Bundle.module.path(forResource: "AVB_PlusGarantie_EP_Zurich_01102019", ofType: "pdf", inDirectory: "assets")!)
    static let billPDFUrl = URL(fileURLWithPath: Bundle.module.path(forResource: "document1", ofType: "pdf", inDirectory: "assets")!)
    static let billPNGUrl = URL(fileURLWithPath: Bundle.module.path(forResource: "document1", ofType: "png", inDirectory: "assets")!)
    static let billJPGGUrl = URL(fileURLWithPath: Bundle.module.path(forResource: "document1", ofType: "jpg", inDirectory: "assets")!)
}
