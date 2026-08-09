//
//  InspectorLayoutSnapshotTests.swift
//  ArchiverLib
//

import ArchiverModels
import ComposableArchitecture
import Foundation
import SwiftUI
import Testing

@testable import ArchiverFeatures

/// Shows the document information form at the width and next to the content it really gets, so the
/// header bar can be judged in proportion rather than on its own.
///
/// This rebuilds the inspector geometry instead of using `DocumentDetailsView`: `.inspector` and
/// sheets are scene level presentations that SwiftUI does not draw into an offscreen host view, and
/// the `drawHierarchy` path that would capture them needs a host application, which an SPM test
/// target cannot have. The column width matches `inspectorColumnWidth(ideal: 400)` in
/// `DocumentDetailsView`.
@MainActor
@Suite(.tags(.snapshots))
struct InspectorLayoutSnapshotTests {

    @Test
    func inspectorBesideTaggedDocument() throws {
        try assertInspectorSnapshot(
            specification: "electricity-bill-january",
            tags: ["bill", "electricity", "2025"],
            isTagged: true,
            suggestedTags: ["energy", "household", "utilities"]
        )
    }

    @Test
    func inspectorBesideUntaggedDocument() throws {
        try assertInspectorSnapshot(
            isTagged: false,
            suggestedTags: ["bill", "electricity", "energy", "household", "utilities"],
            suggestedDates: [
                Date(timeIntervalSince1970: 1_741_737_600),
                Date(timeIntervalSince1970: 1_741_046_400)
            ]
        )
    }

    // MARK: - Helper

    private static let size = CGSize(width: 1_100, height: 760)
    private static let inspectorWidth: CGFloat = 400
    private static let referenceDate = Date(timeIntervalSince1970: 1_742_000_000)

    private func assertInspectorSnapshot(
        specification: String = "",
        tags: Set<String> = [],
        isTagged: Bool,
        suggestedTags: [String] = [],
        suggestedDates: [Date] = [],
        fileID: StaticString = #fileID,
        file filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) throws {
        let url = try makeSnapshotPDF(name: "inspector-layout")
        let document = Document.mock(
            url: url,
            date: Self.referenceDate,
            specification: specification,
            tags: tags,
            isTagged: isTagged,
            downloadStatus: 1
        )

        var formState = DocumentInformationForm.State(document: document)
        formState.suggestedTags = suggestedTags
        formState.suggestedDates = suggestedDates

        // The reducer is intentionally empty: these tests pin the layout, not the behaviour, and a
        // live reducer would race its `onTask` suggestions into the image.
        let store = Store(initialState: formState) {
            EmptyReducer<DocumentInformationForm.State, DocumentInformationForm.Action>()
        }

        let view = HStack(spacing: 0) {
            PDFCustomView(url, highlightDate: nil)

            Divider()

            DocumentInformationFormView(store: store)
                .frame(width: Self.inspectorWidth)
        }

        assertViewSnapshot(
            of: view,
            size: Self.size,
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
    }
}
