//
//  TextReadability.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 10.08.26.
//

import Foundation

/// Tells real document text apart from the mojibake of a broken PDF text layer,
/// where a `ToUnicode` CMap that does not match its font subset turns
/// `Mandatsreferenz (wird von` into `I9Aü9O-P$p$P$Ax31J(Pü3VWA3`.
///
/// Such a substitution scatters digits and symbols through every word, so the
/// share of letters in word-like runs collapses: 0.30 for that layer, never
/// below 0.73 across 265 real archive documents.
///
/// A letter-onto-letter CMap would slip through, and only a dictionary catches
/// that - but none is usable here: measured on the same documents,
/// `NLLanguageRecognizer` rated the broken layer 0.998 (Turkish) against 0.096
/// for real invoices, `NLEmbedding` scores English text and mojibake alike, and
/// `NSSpellChecker` separates worse at 71 ms per document.
public enum TextReadability {

    /// Letters in a run of at least this length count as part of a word.
    static let minimumRunLength = 4

    /// Minimum share of letters that must sit in word-like runs.
    static let minimumWordLetterShare = 0.5

    /// Below this many letters there is not enough evidence to judge.
    static let minimumLetterCount = 50

    /// Returns `true` if `text` plausibly contains real words.
    ///
    /// Errs towards `true`: a `false` re-rasterizes a page or drops AI
    /// suggestions, so only a clear verdict should trigger it.
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
