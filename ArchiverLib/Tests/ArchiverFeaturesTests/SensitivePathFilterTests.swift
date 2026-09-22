//
//  SensitivePathFilterTests.swift
//  ArchiverLib
//

import Diagnostics
import Foundation
import Testing

@testable import ArchiverFeatures

@Suite("SensitivePathFilter")
struct SensitivePathFilterTests {
    @Test("replaces the home directory with ~")
    func replacesHomeDirectory() throws {
        let text = "Report generated at \(NSHomeDirectory())/Library/Application Support"
        let filtered = try #require(SensitivePathFilter.filter(text) as? String)
        #expect(!filtered.contains(NSHomeDirectory()))
        #expect(filtered.contains("~"))
    }

    @Test("replaces .pdf filenames with <document>")
    func replacesPDFNames() throws {
        let text = "Failed to open 2026-01-01--invoice__tax_receipt.pdf"
        let filtered = try #require(SensitivePathFilter.filter(text) as? String)
        #expect(!filtered.contains(".pdf"))
        #expect(!filtered.contains("invoice"))
        #expect(filtered.contains("<document>"))
    }

    @Test("replaces the current username with <user>")
    func replacesUsername() throws {
        let text = "Logged in as \(NSUserName())"
        let filtered = try #require(SensitivePathFilter.filter(text) as? String)
        #expect(!filtered.contains(NSUserName()))
        #expect(filtered.contains("<user>"))
    }

    @Test("filters every value of a [String: String] chapter")
    func filtersDictionaryValues() throws {
        let dictionary = ["file": "2026-01-01--invoice__tax_receipt.pdf"]
        let filtered = try #require(SensitivePathFilter.filter(dictionary) as? [String: String])
        #expect(filtered["file"] == "<document>")
    }
}
