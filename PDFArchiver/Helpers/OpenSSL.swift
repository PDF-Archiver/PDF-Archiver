//
//  OpenSSL.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 23.06.18.
//  Copyright © 2018 Julian Kahnert. All rights reserved.
//

import Foundation
import OpenSSL

struct ReceiptVerificator {
    var bundleIdData: NSData?
    var bundleIdString: String?
    var bundleVersionString: String?
    var opaqueData: NSData?
    var hashData: NSData?
    var iapReceipts = [IAPurchaseReceipt]()
    var expirationDate: Date?

    init() {
        guard let receiptURL = Bundle.main.appStoreReceiptURL,
            let certificateURL = Bundle.main.url(forResource: "AppleIncRootCertificate", withExtension: "cer"),
            let receiptData = NSData(contentsOf: receiptURL),
            let certificateData = NSData(contentsOf: certificateURL) else {
                throw ReceiptError.invalidReceipt
        }
        let bio = BIOWrapper(data: receiptData)
        let p7: UnsafeMutablePointer<PKCS7> = d2i_PKCS7_bio(bio.bio, nil)
        if p7 == nil {
            throw ReceiptError.unexpected
        }
        OpenSSL_add_all_digests()

        let x509Store = X509StoreWrapper()
        let certificate = X509Wrapper(data: certificateData)
        x509Store.addCert(x509: certificate)
        let payload = BIOWrapper()
        guard PKCS7_verify(p7, nil, x509Store.store, nil, payload.bio, 0) == 1 else {
            throw ReceiptError.invalidReceipt
        }

        if let contents = p7.pointee.d.sign.pointee.contents,
            OBJ_obj2nid(contents.pointee.type) == NID_pkcs7_data ,
            let octets = contents.pointee.d.data {
            var ptr: UnsafePointer? = UnsafePointer(octets.pointee.data)
            let end = ptr!.advanced(by: Int(octets.pointee.length))
            var type: Int32 = 0
            var xclass: Int32 = 0
            var length = 0
            ASN1_get_object(&ptr, &length, &type, &xclass, Int(octets.pointee.length))
            guard type == V_ASN1_SET else {
                return
            }
            while ptr! < end {
                ASN1_get_object(&ptr, &length, &type, &xclass, ptr!.distance(to: end))
                guard type == V_ASN1_SEQUENCE else {
                    return
                }

                guard let attrType = ASN1ReadInteger(pointer: &ptr, length: ptr!.distance(to: end)) else {
                    return
                }

                guard let _ = ASN1ReadInteger(pointer: &ptr, length: ptr!.distance(to: end)) else {
                    return
                }

                ASN1_get_object(&ptr, &length, &type, &xclass, ptr!.distance(to: end))
                guard type == V_ASN1_OCTET_STRING else {
                    return
                }

                switch attrType {
                case 2:
                    var strPtr = ptr
                    self.bundleIdData = NSData(bytes: strPtr, length: length)
                    self.bundleIdString = ASN1ReadString(pointer: &strPtr, length: length)
                case 3:
                    var strPtr = ptr
                    self.bundleVersionString = ASN1ReadString(pointer: &strPtr, length: length)
                case 4:
                    self.opaqueData = NSData(bytes: ptr!, length: length)
                case 5:
                    self.hashData = NSData(bytes: ptr!, length: length)
                case 17:
                    let pointer = ptr
                    let iapReceipt = IAPurchaseReceipt(with: pointer!, len: length)
                    self.iapReceipts.append(iapReceipt)
                case 21:
                    var strPtr = ptr
                    self.expirationDate = ASN1ReadDate(pointer: &strPtr, length: length)
                default:
                    break
                }
                ptr = ptr?.advanced(by: length)
            }
        }
    }

    func computedHashData() -> NSData {
        let device = UIDevice.current
        var uuid = device.identifierForVendor?.uuid
        let address = withUnsafePointer(to: &uuid) {UnsafeRawPointer($0)}
        let data = NSData(bytes: address, length: 16)
        var hash = Array<UInt8>(repeating: 0, count: 20)
        var ctx = SHA_CTX()
        SHA1_Init(&ctx)
        SHA1_Update(&ctx, data.bytes, data.length)
        SHA1_Update(&ctx, opaqueData!.bytes, opaqueData!.length)
        SHA1_Update(&ctx, bundleIdData!.bytes, bundleIdData!.length)
        SHA1_Final(&hash, &ctx)
        return NSData(bytes: &hash, length: 20)
    }
}

struct IAPurchaseReceipt {
    var quantity: Int?
    var productIdentifier: String?
    var transactionIdentifier: String?
    var originalTransactionIdentifier: String?
    var purchaseDate: Date?
    var originalPurchaseDate: Date?
    var subscriptionExpirationDate: Date?
    var cancellationDate: Date?
    var webOrderLineItemID: Int?

    init(with asn1Data: UnsafePointer<UInt8>, len: Int) {
        var ptr: UnsafePointer<UInt8>? = asn1Data
        let end = asn1Data.advanced(by: len)
        var type: Int32 = 0
        var xclass: Int32 = 0
        var length = 0
        ASN1_get_object(&ptr, &length, &type, &xclass, Int(len))
        guard type == V_ASN1_SET else {
            return
        }
        while ptr! < end {
            ASN1_get_object(&ptr, &length, &type, &xclass, ptr!.distance(to: end))
            guard type == V_ASN1_SEQUENCE else {
                return
            }

            guard let attrType = ASN1ReadInteger(pointer: &ptr, length: ptr!.distance(to: end)) else {
                return
            }

            guard let _ = ASN1ReadInteger(pointer: &ptr, length: ptr!.distance(to: end)) else {
                return
            }

            ASN1_get_object(&ptr, &length, &type, &xclass, ptr!.distance(to: end))
            guard type == V_ASN1_OCTET_STRING else {
                return
            }

            switch attrType {
            case 1701:
                var pointer = ptr
                self.quantity = ASN1ReadInteger(pointer: &pointer, length: length)
            case 1702:
                var pointer = ptr
                self.productIdentifier = ASN1ReadString(pointer: &pointer, length: length)
            case 1703:
                var pointer = ptr
                self.transactionIdentifier = ASN1ReadString(pointer: &pointer, length: length)
            case 1705:
                var pointer = ptr
                self.originalTransactionIdentifier = ASN1ReadString(pointer: &pointer, length: length)
            case 1704:
                var pointer = ptr
                self.purchaseDate = ASN1ReadDate(pointer: &pointer, length: length)
            case 1706:
                var pointer = ptr
                self.originalPurchaseDate = ASN1ReadDate(pointer: &pointer, length: length)
            case 1708:
                var pointer = ptr
                self.subscriptionExpirationDate = ASN1ReadDate(pointer: &pointer, length: length)
            case 1712:
                var pointer = ptr
                self.cancellationDate = ASN1ReadDate(pointer: &pointer, length: length)
            case 1711:
                var pointer = ptr
                self.webOrderLineItemID = ASN1ReadInteger(pointer: &pointer, length: length)
            default:
                break
            }
            ptr = ptr?.advanced(by: length)
        }
    }
}

// ##################################################################################################################################

class BIOWrapper {
    let bio = BIO_new(BIO_s_mem())
    init(data: NSData) {
        BIO_write(bio, data.bytes, Int32(data.length))
    }

    init() {}

    deinit {
        BIO_free(bio)
    }
}

class X509StoreWrapper {
    let store = X509_STORE_new()
    deinit {
        X509_STORE_free(store)
    }

    func addCert(x509: X509Wrapper) {
        X509_STORE_add_cert(store, x509.x509)
    }
}

class X509Wrapper {
    let x509: UnsafeMutablePointer<X509>!
    init(data: NSData) {
        let certBIO = BIOWrapper(data: data)
        x509 = d2i_X509_bio(certBIO.bio, nil)
    }

    deinit {
        X509_free(x509)
    }
}

func ASN1ReadInteger(pointer ptr: inout UnsafePointer<UInt8>?, length: Int) -> Int? {
    var type: Int32 = 0
    var xclass: Int32 = 0
    var len = 0
    ASN1_get_object(&ptr, &len, &type, &xclass, length)
    guard type == V_ASN1_INTEGER else {
        return nil
    }
    let integer = c2i_ASN1_INTEGER(nil, &ptr, len)
    let result = ASN1_INTEGER_get(integer)
    ASN1_INTEGER_free(integer)
    return result
}

func ASN1ReadString(pointer ptr: inout UnsafePointer<UInt8>?, length: Int) -> String? {
    var strLength = 0
    var type: Int32 = 0
    var xclass: Int32 = 0
    ASN1_get_object(&ptr, &strLength, &type, &xclass, length)
    if type == V_ASN1_UTF8STRING {
        let pointer = UnsafeMutableRawPointer(mutating: ptr!)
        return String(bytesNoCopy: pointer, length: strLength, encoding: String.Encoding.utf8, freeWhenDone: false)
    } else if type == V_ASN1_IA5STRING {
        let pointer = UnsafeMutableRawPointer(mutating: ptr!)
        return String(bytesNoCopy: pointer, length: strLength, encoding: String.Encoding.ascii, freeWhenDone: false)
    }
    return nil
}

func ASN1ReadDate(pointer ptr: inout UnsafePointer<UInt8>?, length: Int) -> Date? {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"
    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    if let dateString = ASN1ReadString(pointer: &ptr, length: length) {
        return dateFormatter.date(from: dateString)
    }
    return nil
}
