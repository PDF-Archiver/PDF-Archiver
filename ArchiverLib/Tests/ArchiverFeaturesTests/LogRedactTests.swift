//
//  LogRedactTests.swift
//  ArchiverLib
//

import Foundation
import Testing

import ArchiverModels

@Suite("LogRedact")
struct LogRedactTests {
    @Test("token is stable for the same URL")
    func tokenIsStableForSameURL() {
        let url = URL(fileURLWithPath: "/Users/jane/Archive/2026/2026-01-01--invoice__tax_receipt.pdf")
        let first = LogRedact.token(url)
        let second = LogRedact.token(url)
        #expect(first == second)
    }

    @Test("token differs for different URLs")
    func tokenDiffersForDifferentURLs() {
        let invoiceURL = URL(fileURLWithPath: "/Users/jane/Archive/2026/2026-01-01--invoice__tax_receipt.pdf")
        let receiptURL = URL(fileURLWithPath: "/Users/jane/Archive/2026/2026-01-02--receipt__groceries.pdf")
        #expect(LogRedact.token(invoiceURL) != LogRedact.token(receiptURL))
    }

    @Test("token does not contain the filename")
    func tokenDoesNotContainFilename() {
        let url = URL(fileURLWithPath: "/Users/jane/Archive/2026/2026-01-01--invoice__tax_receipt.pdf")
        let token = LogRedact.token(url)
        #expect(!token.contains("invoice"))
        #expect(!token.contains("tax"))
        #expect(!token.contains("receipt"))
    }

    @Test("describe does not leak the file path from an NSError's userInfo")
    func describeHidesFilePath() {
        let error = NSError(domain: "TestDomain", code: 42, userInfo: [
            NSFilePathErrorKey: "/Users/jane/Archive/2026/2026-01-01--invoice__tax_receipt.pdf"
        ])
        let description = LogRedact.describe(error)
        #expect(!description.contains("invoice"))
        #expect(!description.contains(".pdf"))
        #expect(description == "TestDomain#42")
    }

    @Test("describe uses a LogSafeError's own description instead of domain#code")
    func describeUsesLogSafeErrorDescription() {
        struct SampleError: LogSafeError {
            var logDescription: String { "sample-failure" }
        }
        #expect(LogRedact.describe(SampleError()) == "sample-failure")
    }
}
