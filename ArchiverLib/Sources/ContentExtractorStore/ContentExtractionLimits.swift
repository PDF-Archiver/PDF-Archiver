//
//  ContentExtractionLimits.swift
//  ArchiverLib
//
//  Resolves the prompt limits that the settings UI and the prompt builder must
//  agree on. Unlike ContentExtractionPromptFactory this file may touch
//  FoundationModels, since the limits depend on the installed model.
//

import Foundation
import FoundationModels

/// The limits the user-facing settings and the on-device prompt share.
public enum ContentExtractionLimits {

    /// Maximum number of characters of the user's custom prompt.
    ///
    /// The settings UI caps its input with this value and the prompt builder
    /// truncates with it, so the character counter never promises more than what
    /// actually reaches the model.
    public static var maxCustomPromptLength: Int {
        // Sizing the cap to the installed model's context window needs iOS 27;
        // earlier systems keep the static cap.
        guard #available(iOS 27, macOS 27, *) else {
            return ContentExtractionPromptFactory.defaultMaxCustomPromptLength
        }

        return ContentExtractionPromptFactory.maxCustomPromptLength(contextSize: SystemLanguageModel.default.contextSize)
    }
}
