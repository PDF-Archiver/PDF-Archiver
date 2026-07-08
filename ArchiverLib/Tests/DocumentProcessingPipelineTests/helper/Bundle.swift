//
//  Bundle.swift
//  ArchiverLib
//

import Foundation

extension Bundle {
    // swiftlint:disable force_unwrapping
    static let longTextPDFUrl = URL(fileURLWithPath: Bundle.module.path(forResource: "AVB_PlusGarantie_EP_Zurich_01102019", ofType: "pdf")!)
    static let billPDFUrl = URL(fileURLWithPath: Bundle.module.path(forResource: "document1", ofType: "pdf")!)
    static let billPNGUrl = URL(fileURLWithPath: Bundle.module.path(forResource: "document1", ofType: "png")!)
    // swiftlint:enable force_unwrapping
}
