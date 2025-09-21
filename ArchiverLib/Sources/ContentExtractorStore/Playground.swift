////
////  Playground.swift
////  ArchiverLib
////
////  Created by Julian Kahnert on 16.09.25.
////
//
// import Playgrounds
//
// #Playground {
//    
//    guard #available(iOS 26.0, macOS 26.0, *) else {
//        print("ContentExtractorStore not available")
//        return
//    }
//    
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
//    let text2 = "Bill of a blue hoddie from tom tailor"
//    
//    
//    
//    let store = ContentExtractorStore()
//    await store.prewarm()
//        
//    let response = try await store.extract(from: text)
//
//
//    for item in store.session.transcript {
//        print(item)
//    }
//    print(response)
//    
////    let contentExtractorStore = ContentExtractorStore()
////    
////    guard let info = try await contentExtractorStore.extract(from: text2) else {
////        print("Model unavailable")
////        return
////    }
////    
////    print("Description: \(info.description)")
////    print("Tags: \(info.tags.joined(separator: ", "))")
//    
////    for item in store.session.transcript {
////        switch item {
////        case .toolCalls(let calls):
////            print(calls)
////            
////        default:
////            break
////        }
////    }
// }
