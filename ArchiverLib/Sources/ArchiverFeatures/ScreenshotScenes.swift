//
//  ScreenshotScenes.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 30.08.26.
//

#if DEBUG
import ArchiverModels
import ComposableArchitecture
import Shared
import SwiftUI

/// A screen rendered as an App Store screenshot, mirroring the tab content of `AppView`.
///
/// Launching the app with `-screenshotScene <rawValue>` shows the scene instead of `RootView`,
/// which is how the UI tests capture the raw screenshots. Every scene is seeded with fixed
/// documents, so a screenshot only changes when the UI does, and is exposed as a `#Preview`.
public enum ScreenshotScene: String, CaseIterable, Sendable {
    case archive

    /// The scene the app was launched for, or `nil` during a normal launch.
    public static var requested: ScreenshotScene? {
        UserDefaults.standard.string(forKey: "screenshotScene").flatMap(ScreenshotScene.init(rawValue:))
    }

    @MainActor @ViewBuilder
    public var view: some View {
        switch self {
        case .archive:
            archiveList
        }
    }

    @MainActor
    private var archiveList: some View {
        seed(documents: Self.archivedDocuments)

        return NavigationStack {
            ArchiveListView(store: Store(initialState: ArchiveList.State()) {
                ArchiveList()
            })
            .navigationTitle(Text("Archive", bundle: #bundle))
        }
    }

    @MainActor
    private func seed(documents newDocuments: [Document]) {
        @Shared(.documents) var documents: IdentifiedArrayOf<Document> = []
        $documents.withLock { $0 = IdentifiedArray(uniqueElements: newDocuments) }
    }

    private static let archivedDocuments: [Document] = [
        document(id: 1, date: (2026, 7, 14), specification: "stromrechnung", tags: ["rechnung", "strom"]),
        document(id: 2, date: (2026, 7, 1), specification: "gehaltsabrechnung", tags: ["arbeit", "gehalt"]),
        document(id: 3, date: (2026, 6, 28), specification: "mietvertrag", tags: ["vertrag", "wohnung"]),
        document(id: 4, date: (2026, 6, 15), specification: "zahnarzt", tags: ["gesundheit", "rechnung"]),
        document(id: 5, date: (2026, 5, 30), specification: "kfz-versicherung", tags: ["auto", "versicherung"]),
        document(id: 6, date: (2026, 5, 12), specification: "internetvertrag", tags: ["internet", "vertrag"]),
        document(id: 7, date: (2026, 4, 20), specification: "steuerbescheid", tags: ["finanzamt", "steuer"]),
        document(id: 8, date: (2026, 4, 3), specification: "handyrechnung", tags: ["mobilfunk", "rechnung"]),
        document(id: 9, date: (2026, 3, 18), specification: "reisekosten", tags: ["arbeit", "reise"]),
        document(id: 10, date: (2026, 3, 1), specification: "kontoauszug", tags: ["bank", "finanzen"])
    ]

    private static func document(id: Document.ID,
                                 date components: (year: Int, month: Int, day: Int),
                                 specification: String,
                                 tags: Set<String>) -> Document {
        let date = Self.date(components)
        let filename = Document.createFilename(date: date, specification: specification, tags: tags)
        return Document(id: id,
                        url: URL(filePath: "/Archive/\(components.year)/\(filename)"),
                        date: date,
                        specification: specification,
                        tags: tags,
                        isTagged: true,
                        sizeInBytes: 512_000,
                        downloadStatus: 1)
    }

    private static func date(_ components: (year: Int, month: Int, day: Int)) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        // A fixed zone keeps the rendered day stable wherever the screenshots are generated.
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .gmt
        return calendar.date(from: DateComponents(year: components.year,
                                                  month: components.month,
                                                  day: components.day)) ?? .distantPast
    }
}

#Preview("App Store: Archive") {
    ScreenshotScene.archive.view
}
#endif
