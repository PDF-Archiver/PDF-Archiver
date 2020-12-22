//
//  IARError+LocalizedError.swift
//  
//
//  Created by Julian Kahnert on 30.10.20.
//

import Foundation
import TPInAppReceipt

extension IARError: LocalizedError {
    public var errorDescription: String? {
        let message: String
        switch self {
            case .initializationFailed(let reason):
                message = "initializationFailed \(reason.description)"
            case .validationFailed(let reason):
                message = "validationFailed \(reason.description)"
            case .purchaseExpired:
                message = "purchaseExpired"
        }

        return "Failed to debug In App Purchase receipt:\n\(message)"
    }
}

extension IARError.ValidationFailureReason: CustomStringConvertible {
    public var description: String {
        switch self {
            case .bundleIdentifierVerification:
                return "bundleIdentifierVerification"
            case .bundleVersionVerification:
                return "bundleVersionVerification"
            case .hashValidation:
                return "hashValidation"
            case .signatureValidation(let reason):
                return "signatureValidation \(reason.description)"
        }
    }
}

extension IARError.ReceiptInitializationFailureReason: CustomStringConvertible {
    public var description: String {
        switch self {
            case .appStoreReceiptNotFound:
                return "appStoreReceiptNotFound"
            case .pkcs7ParsingError:
                return "pkcs7ParsingError"
            case .dataIsInvalid:
                return "dataIsInvalid"
        }
    }

}

extension IARError.SignatureValidationFailureReason: CustomStringConvertible {
    public var description: String {
        switch self {
            case .appleIncRootCertificateNotFound:
                return "appleIncRootCertificateNotFound"
            case .unableToLoadAppleIncRootCertificate:
                return "unableToLoadAppleIncRootCertificate"
            case .unableToLoadAppleIncPublicKey:
                return "unableToLoadAppleIncPublicKey"
            case .unableToLoadiTunesCertificate:
                return "unableToLoadiTunesCertificate"
            case .unableToLoadiTunesPublicKey:
                return "unableToLoadiTunesPublicKey"
            case .unableToLoadWorldwideDeveloperCertificate:
                return "unableToLoadWorldwideDeveloperCertificate"
            case .unableToLoadAppleIncPublicSecKey:
                return "unableToLoadAppleIncPublicSecKey"
            case .receiptIsNotSigned:
                return "receiptIsNotSigned"
            case .receiptSignedDataNotFound:
                return "receiptSignedDataNotFound"
            case .receiptDataNotFound:
                return "receiptDataNotFound"
            case .signatureNotFound:
                return "signatureNotFound"
            case .invalidSignature:
                return "invalidSignature"
            case .invalidCertificateChainOfTrust:
                return "invalidCertificateChainOfTrust"
        }
    }
}
