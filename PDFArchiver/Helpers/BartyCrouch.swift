//
//  BartyCrouch.swift
//  PDFArchiver
//
//  Created by Julian Kahnert on 18.04.19.
//  Copyright © 2019 Julian Kahnert. All rights reserved.
//
//
//  This file is required in order for the `transform` task of the translation helper tool BartyCrouch to work.
//  See here for more details: https://github.com/Flinesoft/BartyCrouch
//

import Foundation

enum BartyCrouch {
    enum SupportedLanguage: String {
        case english = "en"
        case german = "de"
    }

    /// Transformation to (NS)LocalizedString.
    ///
    /// This method will be transformed in the BartyCrouch script build phase into a (NS)LocalizedString.
    /// Example of the transformation can be found [here](https://github.com/Flinesoft/BartyCrouch#localization-workflow-via-transform).
    ///
    /// ```
    /// BartyCrouch.translate(key: "tagging.date-description.untagged-documents",  translations: [.english: "Welcome!"])
    /// (NS)LocalizedString("tagging.date-description.untagged-documents", comment: "")
    /// ```
    ///
    /// - Parameters:
    ///   - key: key name that will be safed in .strings file
    ///   - translations: translation/value that will be safed in .strings file
    ///   - comment: additional comment
    /// - Returns: fall back in case something goes wrong with BartyCrouch transformation
    static func translate(key: String, translations: [SupportedLanguage: String], comment: String? = nil) -> String {
        let typeName = String(describing: BartyCrouch.self)
        let methodName = #function

        print(
            "Warning: [BartyCrouch]",
            "Untransformed \(typeName).\(methodName) method call found with key '\(key)' and base translations '\(translations)'.",
            "Please ensure that BartyCrouch is installed and configured correctly."
        )

        // fall back in case something goes wrong with BartyCrouch transformation
        return "BC: TRANSFORMATION FAILED!"
    }
}
