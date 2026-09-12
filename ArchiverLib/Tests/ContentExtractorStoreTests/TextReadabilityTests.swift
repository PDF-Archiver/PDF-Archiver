//
//  TextReadabilityTests.swift
//  ContentExtractorStoreTests
//

import ArchiverModels
import Foundation
import Testing

@Suite("TextReadability")
struct TextReadabilityTests {

    /// A German document paragraph, run through the substitution alphabet of a
    /// real broken `ToUnicode` CMap (an OCRmyPDF layer that PDFKit extracted as
    /// mojibake). Same shape as the original: letters scattered between digits
    /// and symbols, no word survives intact.
    private let mojibake = """
    Aaz6§naaz6,a§U3mar§HrK§9a66arff§3r1ai§a6z3t,ar§Aia§Kia§Fa7zrHrn§sHa6§Kia§$iasa6Hrn§dbm§ta,Z,ar\
    §pbr3,fl§4i,,a§Ha1a6laigar§Aia§Kar§4a,63n§irra6z3t1§dbr§dia6Zazr§W3nar§3Hs§K3g§Hr,ar§nar3rr,a\
    §übr,bfl§Piatar§U3r.§sHa6§_z6§Pa6,63Har§HrK§_z6a§4ag,attHrn§1ai§Hrga6am§Lr,a6razmarfl
    """

    private let germanText = """
    Sehr geehrte Damen und Herren, anbei erhalten Sie die Rechnung für die Lieferung vom letzten \
    Monat. Bitte überweisen Sie den Betrag innerhalb von vierzehn Tagen auf das unten genannte Konto.
    """

    @Test("Real document text is readable")
    func realTextIsReadable() {
        #expect(TextReadability.isReadable(germanText))
    }

    @Test("A broken text layer is not readable")
    func mojibakeIsNotReadable() {
        #expect(!TextReadability.isReadable(mojibake))
    }

    @Test("Text without spaces stays readable")
    func textWithoutSpacesIsReadable() {
        // PDFKit swallows the spaces of some documents - the words are still
        // intact, so this must not be mistaken for a broken text layer.
        #expect(TextReadability.isReadable(germanText.replacing(" ", with: "")))
    }

    @Test("Number-heavy text stays readable")
    func numberHeavyTextIsReadable() {
        let invoice = """
        Rechnung Nr. 2024-00815 vom 03.05.2024, Kundennummer 571350344, Betrag 1.234,56 EUR,
        Zahlungsziel 14 Tage, IBAN DE02120300000000202051, Steuersatz 19 Prozent auf alle Posten.
        """
        #expect(TextReadability.isReadable(invoice))
    }

    @Test("Too little text is never judged unreadable", arguments: ["", "Rechnung 2024", "AB1 CD2 EF3"])
    func shortTextIsReadable(text: String) {
        #expect(TextReadability.isReadable(text))
    }
}
