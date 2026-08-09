//
//  DocumentInformationFormSnapshotTests.swift
//  ArchiverLib
//

import ArchiverModels
import ComposableArchitecture
import Foundation
import SnapshotTesting
import SwiftUI
import Testing

@testable import ArchiverFeatures

@MainActor
@Suite(.tags(.snapshots))
struct DocumentInformationFormSnapshotTests {

    /// A document that was just dropped into the inbox: nothing filled in, but AI/parser suggestions are available.
    @Test
    func untaggedDocumentWithSuggestions() {
        assertFormSnapshot(
            makeState(
                isTagged: false,
                suggestedDates: [
                    Date(timeIntervalSince1970: 1_741_737_600),
                    Date(timeIntervalSince1970: 1_741_046_400)
                ],
                suggestedTags: ["bill", "electricity", "energy", "household", "utilities"]
            )
        )
    }

    /// An already archived document being edited again - the form is at its longest here.
    @Test
    func taggedDocumentWithTags() {
        assertFormSnapshot(
            makeState(
                specification: "electricity-bill-january",
                tags: ["bill", "electricity", "2025"],
                isTagged: true,
                suggestedTags: ["energy", "household", "utilities"]
            )
        )
    }

    /// The shortest the form ever gets - and the state in which the save button is still reachable without scrolling.
    @Test
    func loadingWithoutSuggestions() {
        assertFormSnapshot(
            makeState(isTagged: false, isLoading: true)
        )
    }

    // MARK: - Helper

    private static let referenceDate = Date(timeIntervalSince1970: 1_742_000_000)

    private func makeState(
        specification: String = "",
        tags: Set<String> = [],
        isTagged: Bool,
        suggestedDates: [Date] = [],
        suggestedTags: [String] = [],
        isLoading: Bool = false
    ) -> DocumentInformationForm.State {
        var state = DocumentInformationForm.State(
            document: .mock(
                date: Self.referenceDate,
                specification: specification,
                tags: tags,
                isTagged: isTagged,
                downloadStatus: 1
            )
        )
        state.suggestedDates = suggestedDates
        state.suggestedTags = suggestedTags
        state.isLoading = isLoading
        return state
    }

    private func assertFormSnapshot(
        _ state: DocumentInformationForm.State,
        fileID: StaticString = #fileID,
        file filePath: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line,
        column: UInt = #column
    ) {
        // The reducer is intentionally empty: these tests pin the layout, not the behaviour, and a
        // live reducer would race its `onTask` suggestions into the image.
        let store = Store(initialState: state) {
            EmptyReducer<DocumentInformationForm.State, DocumentInformationForm.Action>()
        }
        let view = DocumentInformationFormView(store: store)

        #if os(iOS)
        assertSnapshot(
            of: view,
            as: .image(
                precision: Self.precision,
                perceptualPrecision: Self.perceptualPrecision,
                layout: .fixed(width: Self.size.width, height: Self.size.height),
                traits: UITraitCollection(userInterfaceStyle: .dark)
            ),
            named: "ios",
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
        #elseif os(macOS)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = CGRect(origin: .zero, size: Self.size)

        // Without a window the grouped form style renders its backgrounds as transparent.
        let window = NSWindow(
            contentRect: hostingView.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        // Pin the appearance, otherwise the reference depends on the machine's light/dark setting.
        window.appearance = NSAppearance(named: .darkAqua)
        hostingView.layoutSubtreeIfNeeded()

        assertSnapshot(
            of: hostingView,
            as: .image(precision: Self.precision, perceptualPrecision: Self.perceptualPrecision),
            named: "macos",
            fileID: fileID,
            file: filePath,
            testName: testName,
            line: line,
            column: column
        )
        #endif
    }

    /// Matches the inspector column width on macOS and a large sheet detent on iOS.
    private static let size = CGSize(width: 400, height: 800)

    /// Antialiasing of text differs slightly between runs, so compare with human-eye tolerance.
    private static let precision: Float = 0.99
    private static let perceptualPrecision: Float = 0.98
}
