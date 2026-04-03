//
//  ContentExtractorStorePlayground.swift
//  ArchiverLib
//

#if DEBUG && canImport(FoundationModels)
import ArchiverModels
import ContentExtractorStore
import FoundationModels
import Playgrounds

@available(macOS 26.0, *)
extension Transcript.Entry {
    var toolCallCount: Int {
        switch self {
        case .toolCalls(let calls):
            return calls.count
        default:
            return 0
        }
    }
}

// let text = "Bill of a blue hoddie from tom tailor"
let text = """
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

#Playground {

    guard #available(macOS 26.0, *) else { return }

    let store = ContentExtractorStore()

    let documents: [Document] = [
        .mock(specification: "red-shoes", tags: ["kleidung", "rechnung", "test"])
    ]

    let response = try await store.extract(from: text, with: documents)

    print(response?.specification ?? "")
    print(response?.tags ?? [])
}
#endif
