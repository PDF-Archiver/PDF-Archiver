//
//  Bundle.swift
//
//
//  Created by Julian Kahnert on 02.12.20.
//

import Foundation

extension Bundle {
    // swiftlint:disable force_unwrapping
    static let longTextPDFUrl = URL(fileURLWithPath: Bundle.module.path(forResource: "AVB_PlusGarantie_EP_Zurich_01102019", ofType: "pdf")!)
    static let billPDFUrl = URL(fileURLWithPath: Bundle.module.path(forResource: "document1", ofType: "pdf")!)
    static let billPNGUrl = URL(fileURLWithPath: Bundle.module.path(forResource: "document1", ofType: "png")!)
    static let billJPGGUrl = URL(fileURLWithPath: Bundle.module.path(forResource: "document1", ofType: "jpg")!)
    // swiftlint:enable force_unwrapping
}
