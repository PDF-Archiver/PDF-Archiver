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

/// A screen rendered as an App Store screenshot, mirroring what `AppView` shows.
///
/// Launching the app with `-screenshotScene <rawValue>` shows the scene instead of `RootView`,
/// which is how the UI tests capture the raw screenshots. Every scene is seeded with fixed
/// documents, so a screenshot only changes when the UI does, and is exposed as a `#Preview`.
public enum ScreenshotScene: String, CaseIterable, Sendable {
    case archive
    case tagging
    case storage
    case trial
    case inbox
    case statistics

    /// The scene the app was launched for, or `nil` during a normal launch.
    public static var requested: ScreenshotScene? {
        UserDefaults.standard.string(forKey: "screenshotScene").flatMap(ScreenshotScene.init(rawValue:))
    }

    @MainActor @ViewBuilder
    public var view: some View {
        switch self {
        case .archive:
            archiveList

        case .tagging:
            taggingForm

        case .storage:
            storageSelection

        case .trial:
            IAPView(onCancel: {})

        case .inbox:
            inboxList

        case .statistics:
            statisticsView
        }
    }

    // MARK: - Scenes

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
    private var taggingForm: some View {
        seed(documents: Self.archivedDocuments)

        // An untagged document with suggestions is the state the screenshot has to show.
        var state = DocumentInformationForm.State(document: Self.documentBeingTagged,
                                                  suggestedTags: Self.suggestedTags)
        state.suggestedDates = [Self.date(2026, 7, 14), Self.date(2026, 7, 11)]

        return NavigationStack {
            DocumentInformationFormView(store: Store(initialState: state) {
                DocumentInformationForm()
            })
        }
    }

    @MainActor
    private var inboxList: some View {
        seed(documents: Self.archivedDocuments + Self.untaggedDocuments)

        return NavigationStack {
            UntaggedDocumentListView(store: Store(initialState: UntaggedDocumentList.State()) {
                UntaggedDocumentList()
            })
            .navigationTitle(Text("Inbox", bundle: #bundle))
        }
    }

    @MainActor
    private var statisticsView: some View {
        seed(documents: Self.archivedDocuments + Self.untaggedDocuments)

        // The reducer derives these asynchronously; a screenshot needs them present up front.
        var state = Statistics.State()
        state.isLoading = false
        state.yearStats = [2024: 3, 2025: 3, 2026: 4]
        state.untaggedDocuments = Self.untaggedDocuments.count
        state.totalDocuments = Self.archivedDocuments.count + Self.untaggedDocuments.count
        state.totalStorageSize = Measurement(value: 6_144_000, unit: .bytes)
        state.topTags = Self.isGerman
            ? [.init(tag: "rechnung", count: 3), .init(tag: "vertrag", count: 2),
               .init(tag: "arbeit", count: 2), .init(tag: "steuer", count: 1)]
            : [.init(tag: "bill", count: 3), .init(tag: "contract", count: 2),
               .init(tag: "work", count: 2), .init(tag: "tax", count: 1)]

        return NavigationStack {
            StatisticsView(store: Store(initialState: state) {
                Statistics()
            })
            .navigationTitle(Text("Statistics", bundle: #bundle))
        }
    }

    @MainActor
    private var storageSelection: some View {
        NavigationStack {
            StorageSelectionView(store: Store(initialState: StorageSelection.State()) {
                StorageSelection()
            })
        }
    }

    // MARK: - Fixtures

    @MainActor
    private func seed(documents newDocuments: [Document]) {
        @Shared(.documents) var documents: IdentifiedArrayOf<Document> = []
        $documents.withLock { $0 = IdentifiedArray(uniqueElements: newDocuments) }
    }

    /// Filenames are shown verbatim, so a German archive in the English store would read wrong.
    private static var isGerman: Bool {
        Locale.current.language.languageCode?.identifier == "de"
    }

    private static var documentBeingTagged: Document {
        document(id: 99,
                 date: date(2026, 7, 14),
                 specification: isGerman ? "stromrechnung" : "electricity bill",
                 tags: [],
                 isTagged: false)
    }

    private static var suggestedTags: [String] {
        isGerman
            ? ["rechnung", "strom", "wohnung", "energie", "vertrag"]
            : ["bill", "electricity", "home", "energy", "contract"]
    }

    private static var archivedDocuments: [Document] {
        isGerman ? germanDocuments : englishDocuments
    }

    private static let germanDocuments: [Document] = [
        document(id: 1, date: date(2026, 7, 14), specification: "stromrechnung", tags: ["rechnung", "strom"]),
        document(id: 2, date: date(2026, 6, 28), specification: "mietvertrag", tags: ["vertrag", "wohnung"]),
        document(id: 3, date: date(2026, 5, 30), specification: "kfz-versicherung", tags: ["auto", "versicherung"]),
        document(id: 4, date: date(2026, 4, 20), specification: "steuerbescheid", tags: ["finanzamt", "steuer"]),
        document(id: 5, date: date(2025, 11, 9), specification: "zahnarzt", tags: ["gesundheit", "rechnung"]),
        document(id: 6, date: date(2025, 8, 3), specification: "internetvertrag", tags: ["internet", "vertrag"]),
        document(id: 7, date: date(2025, 3, 18), specification: "reisekosten", tags: ["arbeit", "reise"]),
        document(id: 8, date: date(2024, 12, 6), specification: "waschmaschine", tags: ["garantie", "haushalt"]),
        document(id: 9, date: date(2024, 9, 22), specification: "handyrechnung", tags: ["mobilfunk", "rechnung"]),
        document(id: 10, date: date(2024, 5, 2), specification: "kontoauszug", tags: ["bank", "finanzen"])
    ]

    private static let englishDocuments: [Document] = [
        document(id: 1, date: date(2026, 7, 14), specification: "electricity bill", tags: ["bill", "energy"]),
        document(id: 2, date: date(2026, 6, 28), specification: "rental agreement", tags: ["contract", "home"]),
        document(id: 3, date: date(2026, 5, 30), specification: "car insurance", tags: ["car", "insurance"]),
        document(id: 4, date: date(2026, 4, 20), specification: "tax assessment", tags: ["tax", "authority"]),
        document(id: 5, date: date(2025, 11, 9), specification: "dentist invoice", tags: ["health", "invoice"]),
        document(id: 6, date: date(2025, 8, 3), specification: "internet contract", tags: ["contract", "internet"]),
        document(id: 7, date: date(2025, 3, 18), specification: "travel expenses", tags: ["travel", "work"]),
        document(id: 8, date: date(2024, 12, 6), specification: "washing machine", tags: ["household", "warranty"]),
        document(id: 9, date: date(2024, 9, 22), specification: "mobile phone bill", tags: ["bill", "mobile"]),
        document(id: 10, date: date(2024, 5, 2), specification: "bank statement", tags: ["bank", "finance"])
    ]

    /// Freshly scanned, not yet filed - what the inbox is there for. The inbox shows the raw
    /// scanner filename, so these bypass `createFilename` instead of getting an archive name.
    private static var untaggedDocuments: [Document] {
        [("2026-07-18 09-12", 18), ("2026-07-17 17-45", 17), ("2026-07-15 08-03", 15)]
            .enumerated()
            .map { index, scan in
                Document(id: 100 + index,
                         url: URL(filePath: "/Archive/untagged/Scan \(scan.0).pdf"),
                         date: date(2026, 7, scan.1),
                         specification: "Scan \(scan.0)",
                         tags: [],
                         isTagged: false,
                         sizeInBytes: 512_000,
                         downloadStatus: 1)
            }
    }

    private static func document(id: Document.ID,
                                 date: Date,
                                 specification: String,
                                 tags: Set<String>,
                                 isTagged: Bool = true) -> Document {
        let year = Self.calendar.component(.year, from: date)
        let filename = Document.createFilename(date: date, specification: specification, tags: tags)
        return Document(id: id,
                        url: URL(filePath: "/Archive/\(year)/\(filename)"),
                        date: date,
                        specification: specification,
                        tags: tags,
                        isTagged: isTagged,
                        sizeInBytes: 512_000,
                        downloadStatus: 1)
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .distantPast
    }

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        // A fixed zone keeps the rendered day stable wherever the screenshots are generated.
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .gmt
        return calendar
    }()
}

#Preview("App Store: Archive") {
    ScreenshotScene.archive.view
}

#Preview("App Store: Tagging") {
    ScreenshotScene.tagging.view
}

#Preview("App Store: Storage") {
    ScreenshotScene.storage.view
}

#Preview("App Store: Trial") {
    ScreenshotScene.trial.view
}

#Preview("App Store: Inbox") {
    ScreenshotScene.inbox.view
}

#Preview("App Store: Statistics") {
    ScreenshotScene.statistics.view
}
#endif
