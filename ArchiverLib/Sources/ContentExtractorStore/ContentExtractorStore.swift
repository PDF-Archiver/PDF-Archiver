//
//  ContentExtractorStore.swift
//  ArchiveLib
//
//  Created by Julian Kahnert on 20.11.18.
//

import ArchiverModels
import ArchiverStore
import Dependencies
import Foundation
import FoundationModels
import Shared

@available(iOS 26, macOS 26, *)
public actor ContentExtractorStore: Log {
    private static var locale: Locale {
        Locale.current.region == "DE" ? Locale(identifier: "de_DE") : Locale.current
    }

    private static let options = GenerationOptions(
        sampling: .greedy,
        temperature: 0.0,
        maximumResponseTokens: 512
    )

    let session: LanguageModelSession

    init() {
        let tagCountTool = TagCountTool()
        let descriptionTool = DescriptionTool()
        session = LanguageModelSession(
            model: .default,
            tools: [tagCountTool],
            instructions: Instructions {

            // task description
            """
            Your task is to archive documents. To do this, you will receive the content of a new document and you should create a description and tags.
            """

            // Document tags:
            """
            The tags MUST use the existing tags as far as possible.
            Prioritise frequently used tags.
            Use the \(tagCountTool.name) tool to query the existing tags.
            Choose tags by yourself if no tags were provided.
            """

            // Document description:
            """
            The description should briefly describe the content of the document.
            You MUST ALWAYS use the locale \(ContentExtractorStore.locale.identifier) of the user.
            """

                // TODO: this breaks the tooling
//            """
//            You can get example descriptions from the \(descriptionTool.name) tool.
//            """                    

            // Example:
            """
            For an invoice for a blue jumper from Tom Tailor, the following would be the perfect answer:
            - Description: blue hoodie
            - Tags: invoice, clothing, tomtailor
            """
            })
    }

    public static func isAvailable() -> Bool {
        SystemLanguageModel.default.isAvailable
    }

    public func prewarm() {
        session.prewarm()
    }

    public func extract(from text: String) async throws -> Info? {
        guard Self.isAvailable() else { return nil }

        let response = try await session.respond(
            to: text,
            generating: DocumentInformation.self,
            includeSchemaInPrompt: false,
            options: Self.options
        )

        return Info(specification: response.content.description.trimmingCharacters(in: .whitespacesAndNewlines),
                    tags: response.content.tags.prefix(10).map { $0.slugified(withSeparator: "") }
        )
    }
}

@available(iOS 26.0, macOS 26.0, *)
extension ContentExtractorStore {
    @Generable
    struct DocumentInformation {
        @Guide(description: "short document description")
        var description: String

        @Guide(description: "document tags; lowercase; no symbols", .maximumCount(10))
        var tags: [String]
    }

    public struct Info: Sendable, Equatable {
        public let specification: String
        public let tags: [String]
    }
}

// #if canImport(FoundationModels)
//
// import Playgrounds
// import FoundationModels
// #Playground {
//
//    guard #available(macOS 26.0, *) else { return }
//    
//    let store = ContentExtractorStore()
//    await store.prewarm()
//    
////    let text = "Bill of a blue hoddie from tom tailor"
//    let text = """
//        TOM TAILOR
//        TOM TAILOR Retail GmbH
//        Garstedter Weg 14
//        22453 Hamburg
//        öffnungszeiten: Mo-Sa 9:30-20 Uhr
//        1 Jeans uni long Slim Aedan
//        62049720912 1052 31/34
//        4057655718688 1 × 49,99
//        Nachlassbetrag : 10,00EUR
//        49,99
//        10,00
//        39.99
//        Barometer
//        Bonsumme
//        Bonsumme (netto)
//        39,99
//        33,61
//        enthaltene MWST 19% 6,38
//        gegeben : Bar
//        Rückgeld:
//        40.00
//        0,01
//        Vielen Dank für Ihren Einkauf!
//        Es bediente Sie:
//        Ömer G.
//        Bon: 79535 05.01.17 13:45:30
//        Filiale: RT100089
//        Kasse: 01
//        Store Oldenburg Denim
//        Schlosshöfe
//        26122 01 denburg
//        Tel
//        USt-IdNr: DE 252291581
//        TOM TAILOR COLLECTORS CLUB
//        Mitglied werden und Vorteile genießen!
//        Rund um die Uhr einkaufen im
//        E-Shop unter TOM-TAILOR. DE
//        """
//    
//    let response = try await store.extract(from: text)
//
//
////    for item in store.session.transcript {
////        print(item)
////    }
//    for item in store.session.transcript {
//        switch item {
//        case .toolCalls(let calls):
//            print(calls)
//            
//        default:
//            break
//        }
//    }
//    
//    print(response)
// }
// #endif
