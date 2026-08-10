//
//  TextReadability.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 10.08.26.
//

import Foundation

/// Heuristic that tells apart real document text from the mojibake a broken PDF
/// text layer produces.
///
/// Scanners and third-party OCR tools sometimes ship a text layer whose
/// `ToUnicode` CMap does not match the embedded font subset. The PDF then
/// *has* text - `PDFPage.string` returns 2000 characters - but every letter is
/// mapped to an arbitrary other character, so the result reads like
/// `I9Aü9O-P$p$P$Ax31J(Pü3VWA3`. Such text must neither count as a usable text
/// layer nor be handed to the language model.
///
/// The signal used is the share of letters that sit in word-like runs: a
/// substitution of this kind scatters digits and symbols across every word, so
/// long uninterrupted letter runs practically disappear. Measured over 265 real
/// archive documents the share never dropped below 0.73 - not for number-heavy
/// invoices and payslips, and not where PDFKit swallowed every space - while
/// the broken layer above scores 0.30.
///
/// # Known blind spot
///
/// A CMap that maps letters onto *letters* only produces intact-looking runs
/// and scores like real text. Broken CMaps reinterpret glyph IDs through a
/// standard encoding, which lands mostly in the digit and punctuation range, so
/// this stays theoretical - but only a dictionary catches it.
///
/// A dictionary is not used because it needs the document's language, and the
/// SDK cannot supply it here: measured against the same 265 documents,
/// `NLLanguageRecognizer` rated the broken layer 0.998 (Turkish) while real
/// German invoices scored as low as 0.096, `NLEmbedding` scored an English
/// letter and the mojibake identically (0.000) and covers few languages, and
/// `NSSpellChecker` separated worse than this heuristic (0.31 vs 0.50) at
/// 71 ms per document.
public enum TextReadability {

    /// Letters in an uninterrupted run of at least this length are counted as
    /// belonging to a word.
    static let minimumRunLength = 4

    /// Minimum share of letters that must sit in word-like runs.
    static let minimumWordLetterShare = 0.5

    /// Below this many letters the sample is too small to judge - a short
    /// header is not enough evidence to declare a document unreadable.
    static let minimumLetterCount = 50

    /// Returns `true` if `text` plausibly contains real words.
    ///
    /// Errs on the side of `true`: both call sites act destructively on a
    /// `false` (re-rasterizing a page, dropping AI suggestions), so only a
    /// clear verdict should trigger them.
    public static func isReadable(_ text: String) -> Bool {
        var totalLetters = 0
        var wordLetters = 0
        var runLength = 0

        for character in text {
            if character.isLetter {
                runLength += 1
                continue
            }
            totalLetters += runLength
            if runLength >= minimumRunLength {
                wordLetters += runLength
            }
            runLength = 0
        }
        totalLetters += runLength
        if runLength >= minimumRunLength {
            wordLetters += runLength
        }

        guard totalLetters >= minimumLetterCount else { return true }
        return Double(wordLetters) / Double(totalLetters) >= minimumWordLetterShare
    }
}
