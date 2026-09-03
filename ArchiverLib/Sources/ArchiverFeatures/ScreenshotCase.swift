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
/// The shots tell one story about the same TOM TAILOR receipt: it waits in the inbox (`20-inbox`),
/// gets its date, description and the first of its tags (`02-tagging`), and is found in the
/// archive under both tags afterwards (`01-archive`, `03-document`).
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
            $0.textAnalyser = screenshotCase.textAnalyser
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

        case .document:
            state.archiveList.searchText = Self.receiptSearchTerm

        case .tagging, .trial, .inbox:
            state.selectedTab = .inbox

        case .statistics:
            state.selectedTab = .statistics
            state.statistics.apply(documents: state.documents)
        }

        return state
    }

    /// Opens the document the shot is about, once the window exists.
    ///
    /// Not part of `initialState`: SwiftUI does not push a `navigationDestination` that is already
    /// set when the stack first appears, so the shot would show the list instead of the document.
    @MainActor
    func activate(_ store: StoreOf<AppFeature>) {
        switch self {
        case .tagging:
            store.send(.untaggedDocumentList(.selectionChanged(Self.receiptId)))

        case .document:
            store.send(.archiveList(.selectionChanged(Self.receiptId)))

        case .archive, .trial, .inbox, .statistics:
            break
        }
    }

    /// Renders the case the way the app does, for design iteration without a simulator run.
    @MainActor
    var preview: some View {
        withDependencies {
            $0.archiveStore = archiveStore
            $0.textAnalyser = textAnalyser
        } operation: {
            let store = Store(initialState: initialState) { AppFeature() }
            return AppView(store: store)
                .task { activate(store) }
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
            getTagSuggestionsSimilarTo: { tags in suggestedTags.filter { !tags.contains($0) } },
            // What the app recognises from the scan: its date and description, but no tag yet.
            parseFilename: { _ in (Self.receiptDate, Self.receiptSpecification, nil) },
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
        case .archive, .document:
            // The receipt has been filed by now, the rest of the scans still wait in the inbox.
            return Self.archivedDocuments + [Self.receipt(isTagged: true)] + Self.scannedDocuments

        case .tagging, .trial, .inbox, .statistics:
            return Self.archivedDocuments + [Self.receipt(isTagged: false)] + Self.scannedDocuments
        }
    }

    // MARK: - Fixtures

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

    /// The receipt in the two states the flow shows it in: the scan that arrived in the inbox, and
    /// the document that is filed under `receiptTags` afterwards.
    private static func receipt(isTagged: Bool) -> Document {
        let filename = isTagged
            ? Document.createFilename(date: receiptDate, specification: receiptSpecification, tags: Set(receiptTags))
            : "\(scanName).pdf"

        return Document(id: receiptId,
                        url: receiptURL(named: filename) ?? URL(filePath: "/Archive/2017/\(filename)"),
                        date: receiptDate,
                        // Untagged documents show up under the name the scanner gave them.
                        specification: isTagged ? receiptSpecification : scanName,
                        tags: isTagged ? Set(receiptTags) : [],
                        isTagged: isTagged,
                        sizeInBytes: 48_000,
                        downloadStatus: 1)
    }

    /// Stands in for OCR and Apple Intelligence, so the tagging shot cannot drift with what a
    /// local model makes of the page today.
    ///
    /// The first tag arrives as a file tag while the parsed filename carries none, because that is
    /// the one combination the form fills mid-process: one tag picked, the rest still suggested.
    private var textAnalyser: TextAnalyserDependency {
        let suggestedTags = Self.receiptSuggestedTags
        let pickedTags = Array(Self.receiptTags.prefix(1))
        return TextAnalyserDependency(
            getTextFrom: { _ in Self.receiptText },
            parseDateFrom: { _ in [] },
            parseTagsFrom: { _ in Set(suggestedTags) },
            getFileTagsFrom: { _ in pickedTags }
        )
    }

    private static let receiptId = 200

    /// Only the date and tag parsers read this, and both are fixtures - the page itself is what
    /// the shot shows.
    private static let receiptText = "TOM TAILOR Retail GmbH"

    /// The receipt prints 05.01.17 - a date the shots must not contradict.
    private static let receiptDate = date(2017, 1, 5)

    private static let receiptSpecification = "tom-tailor-jeans"

    private static let scanName = "Scan 2017-01-05"

    /// The tags the flow agrees on: the tagging shot has the first one picked, the archive shows
    /// the document filed under both. The second one is what `searchTerm` finds.
    private static var receiptTags: [String] {
        isGerman ? ["kleidung", "rechnung"] : ["clothing", "invoice"]
    }

    private static var receiptSuggestedTags: [String] {
        isGerman ? ["kleidung", "rechnung", "jeans", "quittung", "tomtailor"]
                 : ["clothing", "invoice", "jeans", "receipt", "tomtailor"]
    }

    /// The query the archive shots search for, shared by iPhone and Mac so both tell one story.
    private static var searchTerm: String {
        isGerman ? "rechnung" : "invoice"
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
        document(id: 1, date: date(2026, 7, 14), specification: "electricity bill", tags: ["invoice", "energy"]),
        document(id: 2, date: date(2026, 6, 28), specification: "rental agreement", tags: ["contract", "home"]),
        document(id: 3, date: date(2026, 5, 30), specification: "car insurance", tags: ["car", "insurance"]),
        document(id: 4, date: date(2026, 4, 20), specification: "tax assessment", tags: ["tax", "authority"]),
        document(id: 5, date: date(2025, 11, 9), specification: "dentist invoice", tags: ["health", "invoice"]),
        document(id: 6, date: date(2025, 8, 3), specification: "internet contract", tags: ["contract", "internet"]),
        document(id: 7, date: date(2025, 3, 18), specification: "travel expenses", tags: ["travel", "work"]),
        document(id: 8, date: date(2024, 12, 6), specification: "washing machine", tags: ["household", "warranty"]),
        document(id: 9, date: date(2024, 9, 22), specification: "mobile phone bill", tags: ["invoice", "mobile"]),
        document(id: 10, date: date(2024, 5, 2), specification: "bank statement", tags: ["bank", "finance"])
    ]

    /// Freshly scanned, not yet filed - what the inbox is there for. The inbox shows the raw
    /// scanner filename, so these bypass `createFilename` instead of getting an archive name.
    private static var scannedDocuments: [Document] {
        [("2026-07-18 09-12", 18), ("2026-07-17 17-45", 17), ("2026-07-15 08-03", 15),
         ("2026-07-14 12-58", 14), ("2026-07-11 19-24", 11), ("2026-07-09 07-36", 9),
         ("2026-07-02 16-08", 2)]
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
