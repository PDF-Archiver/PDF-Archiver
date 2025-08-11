//
//  PDFProcessingTests.swift
//
//
//  Created by Julian Kahnert on 01.12.20.
//

import Foundation
import PDFKit
import Shared
import Testing

@testable import ArchiverDocumentProcessing

@StorageActor
final class PDFProcessingTests {

    nonisolated private static let tempFolder = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    // swiftlint:disable:next force_unwrapping
    private static let referenceDocument = PDFDocument(url: Bundle.billPDFUrl)!

    init() throws {
        try FileManager.default.createDirectory(at: Self.tempFolder, withIntermediateDirectories: true, attributes: nil)
    }

    deinit {
        try! FileManager.default.removeItem(at: Self.tempFolder)
    }

    private static func levenshtein(_ lhs: String, _ rhs: String) -> Int {
        let lhsArray = Array(lhs)
        let rhsArray = Array(rhs)

        let (m, n) = (lhsArray.count, rhsArray.count)
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        for i in 0...m { dp[i][0] = i }
        for j in 0...n { dp[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                if lhsArray[i - 1] == rhsArray[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1]
                } else {
                    dp[i][j] = min(
                        dp[i - 1][j] + 1,    // Deletion
                        dp[i][j - 1] + 1,    // Insertion
                        dp[i - 1][j - 1] + 1 // Substitution
                    )
                }
            }
        }

        return dp[m][n]
    }

    @Test
    // swiftlint:disable:next function_body_length
    func testPDFInput() async throws {
        let exampleUrl = Self.tempFolder.appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("pdf")
        try FileManager.default.copyItem(at: Bundle.longTextPDFUrl, to: exampleUrl)
        let inputDocument = try #require(PDFDocument(url: exampleUrl))
        let inputDocumentString = try #require(inputDocument.string)
        let inputDocumentData = try #require(inputDocument.dataRepresentation())

        var documentUrl: URL?
        let operation = PDFProcessingOperation(of: .pdf(pdfData: inputDocumentData, url: exampleUrl),
                                               destinationFolder: Self.tempFolder) { url in
            documentUrl = url
        }

        await operation.process()

        let outputUrl = try #require(documentUrl)
        let document = try #require(PDFDocument(url: outputUrl))
        let documentString = try #require(document.string)

        // pdf content should not change during processing
        #expect(inputDocumentString == documentString)
        #expect(inputDocument.pageCount == document.pageCount)
    }

    @Test
    func testPNGInput() async throws {
        let image = try #require(PlatformImage(contentsOf: Bundle.billPNGUrl))

        var documentUrl: URL?
        let operation = PDFProcessingOperation(of: .images([image]),
                                               destinationFolder: Self.tempFolder) { url in
            documentUrl = url
        }

        await operation.process()

        let outputUrl = try #require(documentUrl)
        let document = try #require(PDFDocument(url: outputUrl))

        #expect(document.pageCount == Self.referenceDocument.pageCount)

        #expect(document.pageCount == 1)
        let creatorAttribute = try #require(document.documentAttributes?[PDFDocumentAttribute.creatorAttribute] as? String)
        #expect(creatorAttribute.starts(with: "PDF Archiver"))
        let content = try #require(document.string)
        #expect(!content.isEmpty)
        #expect(content.contains("TOM TAILOR"))
        #expect(content.contains("Oldenburg"))
        #expect(content.contains("Vielen Dank"))
        #expect(content.contains("Nachlassbetrag"))
        #expect(content.contains("Mitglied werden"))
        #expect(content.contains("Bon: 79535 05.01.17 13:45:30"))

        let referenceContent = """
            TOM TAILOR
            TOM TAILOR Retail GmbH
            Garstedter Weg 14
            22453 Hamburg
            öffnungszeiten: Mo-Sa 9:30-20 Uhr
            1 Jeans uni long Slim Aedan
            62049720912 1052 31/34
            4057655718688 1 × 49,99
            Nachlassbetrag : 10,00EUR
            49,99
            10.00
            39.99
            Barometer
            Bonsumme
            Bonsumme (netto)
            39,99
            33,61
            enthaltene MWST 19% 6,38
            gegeben : Bar
            Rückgeld:
            40.00
            0,01
            Vielen Dank für Ihren Einkauf!
            Es bediente Sie:
            Ömer G.
            Bon: 79535 05.01.17 13:45:30
            Filiale: RT100089
            Kasse: 01
            Store Oldenburg Denim
            Schlosshöfe
            26122 01 denburg
            Tel
            e... USt-IdNr: DE 252291581
            TOM TAILOR COLLECTORS CLUB
            Mitglied werden und Vorteile genießen!
            Rund um die Uhr einkaufen im
            E-Shop unter TOM-TAILOR.DE
            """
        #expect(Self.levenshtein(content, referenceContent) < 10)
    }

    @Test
    func testJPGInput() async throws {
        let image = try #require(PlatformImage(contentsOf: Bundle.billJPGGUrl))

        var documentUrl: URL?
        let operation = PDFProcessingOperation(of: .images([image]),
                                                     destinationFolder: Self.tempFolder) { url in
            documentUrl = url
        }

        await operation.process()

        let outputUrl = try #require(documentUrl)
        let document = try #require(PDFDocument(url: outputUrl))

        #expect(document.pageCount == Self.referenceDocument.pageCount)

        #expect(document.pageCount == 1)
        let creatorAttribute = try #require(document.documentAttributes?[PDFDocumentAttribute.creatorAttribute] as? String)
        #expect(creatorAttribute.starts(with: "PDF Archiver"))
        let content = try #require(document.string)
        #expect(!content.isEmpty)
        #expect(content.contains("TOM TAILOR"))
        #expect(content.contains("Oldenburg"))
        #expect(content.contains("Vielen Dank"))
        #expect(content.contains("Nachlassbetrag"))
        #expect(content.contains("Mitglied werden"))

        let referenceContent = """
            TOM TAILOR
            TOM TAILOR Retail GmbH
            Garstedter Weg 14
            22453 Hamburg
            öffnungszeiten: Mo-Sa 9:30-20 Uhr
            1 Jeans uni long Slim Aedan
            62049720912 1052 31/34
            4057655718688 1 × 49,99
            Nachlassbetrag : 10,00EUR
            49,99
            10,00
            39.99
            Barometer
            Bonsumme
            Bonsumme (netto)
            39,99
            33,61
            enthaltene MWST 19% 6,38
            gegeben : Bar
            Rückgeld:
            40.00
            0,01
            Vielen Dank für Ihren Einkauf!
            Es bediente Sie:
            Ömer G.
            Bon: 79535 05.01.17 13:45:30
            Filiale: RT100089
            Kasse: 01
            Store Oldenburg Denim
            Schlosshöfe
            26122 01 denburg
            Tel
            USt-IdNr: DE 252291581
            TOM TAILOR COLLECTORS CLUB
            Mitglied werden und Vorteile genießen!
            Rund um die Uhr einkaufen im
            E-Shop unter TOM-TAILOR. DE
            """
        #expect(Self.levenshtein(content, referenceContent) < 10)
    }

    @Test
    func testJPGMultiplePages() async throws {
        let image = try #require(PlatformImage(contentsOf: Bundle.billJPGGUrl))

        var documentUrl: URL?
        let operation = PDFProcessingOperation(of: .images([image, image, image]),
                                               destinationFolder: Self.tempFolder) { url in
            documentUrl = url
        }

        await operation.process()

        let outputUrl = try #require(documentUrl)
        let document = try #require(PDFDocument(url: outputUrl))

        #expect(document.pageCount == 3)
        let creatorAttribute = try #require(document.documentAttributes?[PDFDocumentAttribute.creatorAttribute] as? String)
        #expect(creatorAttribute.starts(with: "PDF Archiver"))
        let content = try #require(document.string)
        #expect(!content.isEmpty)
        #expect(content.contains("TOM TAILOR"))
        #expect(content.contains("Oldenburg"))
        #expect(content.contains("Vielen Dank"))
        #expect(content.contains("Nachlassbetrag"))
        #expect(content.contains("Mitglied werden"))

        let referenceContent = """
            TOM TAILOR
            TOM TAILOR Retail GmbH
            Garstedter Weg 14
            22453 Hamburg
            öffnungszeiten: Mo-Sa 9:30-20 Uhr
            1 Jeans uni long Slim Aedan
            62049720912 1052 31/34
            4057655718688 1 × 49,99
            Nachlassbetrag : 10,00EUR
            49,99
            10,00
            39.99
            Barometer
            Bonsumme
            Bonsumme (netto)
            39,99
            33,61
            enthaltene MWST 19% 6,38
            gegeben : Bar
            Rückgeld:
            40.00
            0,01
            Vielen Dank für Ihren Einkauf!
            Es bediente Sie:
            Ömer G.
            Bon: 79535 05.01.17 13:45:30
            Filiale: RT100089
            Kasse: 01
            Store Oldenburg Denim
            Schlosshöfe
            26122 01 denburg
            Tel
            USt-IdNr: DE 252291581
            TOM TAILOR COLLECTORS CLUB
            Mitglied werden und Vorteile genießen!
            Rund um die Uhr einkaufen im
            E-Shop unter TOM-TAILOR. DE
            """

        #expect(Self.levenshtein(content, [referenceContent, referenceContent, referenceContent].joined(separator: "\n")) < 10)
    }
 }
