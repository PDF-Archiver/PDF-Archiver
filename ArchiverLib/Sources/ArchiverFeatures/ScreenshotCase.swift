//
//  ScreenshotCase.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 03.09.26.
//

#if DEBUG
import ArchiverModels
import ArchiverStore
import ComposableArchitecture
import Shared
import SwiftUI

/// One App Store screenshot, expressed as the state the real app starts in.
///
/// `-screenshotCase <rawValue>` makes `RootView` build its store from fixtures instead of the live
/// archive, so every shot goes through `AppView` and shows the app's own chrome. The raw value is
/// the launch argument and the output filename in one.
///
/// The numbers follow the marketing shot list, which is why they skip: 04 to 07 are camera,
/// Spotlight, Files and home screen shots that no app run can produce. `document` is a Mac-only
/// shot - on iPhone that number is a camera photo.
public enum ScreenshotCase: String, CaseIterable, Sendable {
    case archive = "01-archive"
    case tagging = "02-tagging"
    case document = "03-document"
    case trial = "08-trial"
    case inbox = "20-inbox"
    case statistics = "21-statistics"

    /// The case the app was launched for, or `nil` during a normal launch.
    public static var requested: ScreenshotCase? {
        UserDefaults.standard.string(forKey: "screenshotCase").flatMap(ScreenshotCase.init(rawValue:))
    }

    /// Replaces the live archive with the case's fixtures.
    ///
    /// Called from the app initializer: `prepareDependencies` has to run before the first
    /// dependency is accessed, which the root store does as soon as it is built.
    public static func prepareIfRequested() {
        guard let screenshotCase = requested else { return }

        prepareDependencies {
            $0.context = .preview
            $0.archiveStore = screenshotCase.archiveStore
        }
    }

    /// The state the app starts in, already settled - a screenshot must not wait for a load.
    ///
    /// Everything derived from the documents goes through the same helpers the reducers use, so
    /// the tab suggestions, counts and statistics cannot drift from what a live archive shows.
    @MainActor
    var initialState: AppFeature.State {
        // A launch argument cannot do this: it arrives as a string, and the shared key reads a Bool.
        @Shared(.tutorialShown) var tutorialShown: Bool = false
        $tutorialShown.withLock { $0 = true }

        @Shared(.premiumStatus) var premiumStatus: PremiumStatus = .loading
        $premiumStatus.withLock { $0 = self.premiumStatus }

        var state = AppFeature.State()
        state.apply(documents: documents)
        state.isDocumentLoading = false

        switch self {
        case .archive:
            state.archiveList.searchText = Self.searchTerm

        case .tagging:
            state.selectedTab = .inbox
            state.untaggedDocumentList.documentDetails = Self.details(for: Self.receipt(isTagged: false),
                                                                     showInspector: true)

        case .document:
            let receipt = Self.receipt(isTagged: true)
            state.archiveList.searchText = Self.receiptSearchTerm
            state.archiveList.$selectedDocumentId.withLock { $0 = receipt.id }
            // No inspector here: the point of the shot is the filed document itself.
            state.archiveList.documentDetails = Self.details(for: receipt, showInspector: false)

        case .trial, .inbox:
            state.selectedTab = .inbox

        case .statistics:
            state.selectedTab = .statistics
            state.statistics.apply(documents: state.documents)
        }

        return state
    }

    /// Renders the case the way the app does, for design iteration without a simulator run.
    @MainActor
    var preview: some View {
        withDependencies {
            $0.archiveStore = archiveStore
        } operation: {
            AppView(store: Store(initialState: initialState) { AppFeature() })
        }
    }

    /// Yields the fixtures once, so the reducer derives its state from them exactly as it would
    /// from a real archive. Without the override the live store would load in and wipe them.
    private var archiveStore: ArchiveStoreDependency {
        let documents = documents
        let suggestedTags = Self.receiptSuggestedTags
        return ArchiveStoreDependency(
            documentChanges: { AsyncStream { $0.yield(documents) } },
            reloadDocuments: { },
            getDocuments: { documents },
            isLoading: { AsyncStream { $0.yield(false) } },
            startDownloadOf: { _ in },
            deleteDocumentAt: { _ in },
            getTagSuggestionsFor: { _ in suggestedTags },
            getTagSuggestionsSimilarTo: { _ in suggestedTags },
            // The fixtures are already the parsed result; anything else here would overwrite them.
            parseFilename: { _ in (nil, nil, nil) },
            saveDocument: { _, _ in },
            setArchiveStorageType: { _ in }
        )
    }

    private var premiumStatus: PremiumStatus {
        switch self {
        case .trial:
            return .inactive

        case .archive, .tagging, .document, .inbox, .statistics:
            return .active
        }
    }

    private var documents: [Document] {
        switch self {
        case .archive:
            return Self.archivedDocuments

        case .tagging:
            return [Self.receipt(isTagged: false)] + Self.archivedDocuments

        case .document:
            return [Self.receipt(isTagged: true)] + Self.archivedDocuments

        case .trial, .inbox, .statistics:
            return Self.archivedDocuments + Self.untaggedDocuments
        }
    }

    // MARK: - Fixtures

    @MainActor
    private static func details(for document: Document, showInspector: Bool) -> DocumentDetails.State {
        var details = DocumentDetails.State(document: Shared(value: document))
        details.showInspector = showInspector
        details.documentInformationForm.suggestedTags = receiptSuggestedTags
        return details
    }

    /// The TOM TAILOR receipt checked into the test assets, passed in as `-screenshotAsset`.
    /// Nothing is bundled, so the receipt's address and VAT number stay out of the shipped app.
    ///
    /// Copied to a temporary file under `filename`, because two things need it at once: `PDFView`
    /// needs a readable file, and the archive search filters on the last path component.
    private static func receiptURL(named filename: String) -> URL? {
        guard let source = UserDefaults.standard.string(forKey: "screenshotAsset")
            .map({ URL(filePath: $0) }) else { return nil }

        let destination = URL.temporaryDirectory.appending(component: filename)
        try? FileManager.default.removeItem(at: destination)
        guard (try? FileManager.default.copyItem(at: source, to: destination)) != nil else { return nil }
        return destination
    }

    /// Date and description as the app recognises them from the receipt: bought 05.01.2017.
    /// The two tags are set either way - untagged with tags chosen is what the tagging shot shows.
    private static func receipt(isTagged: Bool) -> Document {
        let date = date(2017, 1, 5)
        let specification = "tom-tailor-jeans"
        let tags: Set<String> = isGerman ? ["kleidung", "quittung"] : ["clothing", "receipt"]

        // Untagged documents sit in the inbox under the name the scanner gave them.
        let filename = isTagged
            ? Document.createFilename(date: date, specification: specification, tags: tags)
            : "Scan 2017-01-05.pdf"

        return Document(id: 200,
                        url: receiptURL(named: filename) ?? URL(filePath: "/Archive/2017/\(filename)"),
                        date: date,
                        specification: specification,
                        tags: tags,
                        isTagged: isTagged,
                        sizeInBytes: 48_000,
                        downloadStatus: 1)
    }

    private static var receiptSuggestedTags: [String] {
        isGerman ? ["tomtailor", "jeans", "bekleidung"] : ["tomtailor", "jeans", "apparel"]
    }

    /// The query the archive shots search for, shared by iPhone and Mac so both tell one story.
    private static var searchTerm: String {
        isGerman ? "rechnung" : "bill"
    }

    private static let receiptSearchTerm = "tom tailor"

    /// Filenames are shown verbatim, so a German archive in the English store would read wrong.
    private static var isGerman: Bool {
        Locale.current.language.languageCode?.identifier == "de"
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

#Preview("App Store: 01 Archive") {
    ScreenshotCase.archive.preview
}

#Preview("App Store: 02 Tagging") {
    ScreenshotCase.tagging.preview
}

#Preview("App Store: 03 Document") {
    ScreenshotCase.document.preview
}

#Preview("App Store: 08 Trial") {
    ScreenshotCase.trial.preview
}

#Preview("App Store: 20 Inbox") {
    ScreenshotCase.inbox.preview
}

#Preview("App Store: 21 Statistics") {
    ScreenshotCase.statistics.preview
}
#endif
