import Dependencies
import Foundation
import Testing

@testable import ArchiverFeatures

@MainActor
struct PDFDropHandlerTests {
    /// The error reaches the caller, which shows it; the button must not keep spinning behind it.
    @Test
    func aFailedImportResetsTheButtonAndRethrows() async throws {
        let missingFile = URL(filePath: "/nonexistent/\(UUID().uuidString).pdf")

        try await withDependencies {
            $0.documentProcessor.processStagedFiles = { }
        } operation: {
            let handler = PDFDropHandler()

            await #expect(throws: (any Error).self) {
                try await handler.handleImport(of: missingFile)
            }

            #expect(handler.documentProcessingState == .noDocument)
        }
    }
}
