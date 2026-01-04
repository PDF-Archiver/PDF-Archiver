//
//  OpenDocumentIntent.swift
//  ArchiverLib
//
//  Created by Julian Kahnert on 23.09.25.
//

// TODO: add this again
// import Foundation
// import AppIntents
// import CoreSpotlight
//
//// @AssistantIntent(schema: .books.openBook)
// struct OpenDocument: OpenIntent {
//    
//    static let title: LocalizedStringResource = "Open Document"
//
//    static let description = IntentDescription("Displays document details in the app.")
//    
//    static var parameterSummary: some ParameterSummary {
//        Summary("Open \(\.$target)")
//    }
//    
//    /// `OpenIntent` requires a `target` property to represent the entity opening in the app.
//    @IntentParameter(title: "Document", description: "The trail to get information for.")
//    var target: DocumentEntity
//    
//    /// Because this intent conforms to `OpenIntent`, the system opens the app when the intent runs,
//    /// so you don't need to implement the `openAppWhenRun`property.
//    // static var openAppWhenRun: Bool = true
//    
//    /**
//     This intent doesn't need a `perform()` method because it conforms to `URLRepresentableIntent`.
//     When this intent runs, the system takes the URL that `target` declares through its `URLRepresentableEntity` conformance,
//     and calls the standard path for opening a universal link URL in the app using that URL.
//     */
//     @MainActor
//    func perform() async throws -> some IntentResult {
//         
//         print(target)
//         exit(1)
//         return .result()
//     }
// }
//
//
//
// extension Document {
//    var searchableAttributes: CSSearchableItemAttributeSet {
//        let attributes = CSSearchableItemAttributeSet(contentType: .pdf)
//        attributes.title = url.lastPathComponent
//        attributes.contentModificationDate = date
//        attributes.keywords = tags.sorted()
////        return attributes
////
////        let specification = document.specification
////        guard !specification.isEmpty else { return nil }
////
//        
////        attributes.displayName = specification + " " + tags.sorted().map({ "#\($0)" }).joined(separator: " ")
////        attributes.containerDisplayName = "\(Calendar.current.component(.year, from: date))"
//        attributes.title = specification
//        attributes.url = url
////                                    let icon = bookmark.displayIcon
////                                    attributes.thumbnailData = icon.pngData()
//
//        attributes.identifier = "\(id)"
//        return attributes
//    }
//    
//    public var hideInSpotlight: Bool {
//        specification.isEmpty
//    }
// }
//
// import AppIntents
//
// public struct DocumentEntity: AppEntity {
//    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
//        TypeDisplayRepresentation(
//            name: LocalizedStringResource("Document"),
////            numericFormat: LocalizedStringResource("\(placeholder: .int) trails", table: "AppIntents")
//        )
//    }
//    
//    public static let defaultQuery = DocumentEntityQuery()
//
//    public var id: Document.ID
//  
//    var url: URL
//    @Property var date: Date
//    @Property var specification: String
//    @Property var tags: Set<String>
//    
//    public var displayRepresentation: DisplayRepresentation {
////        DisplayRepresentation(
//        DisplayRepresentation(title: "\(specification)",
//                              subtitle: "\(tags.sorted().map({ "#\($0)" }).joined(separator: " "))",
//                              image: DisplayRepresentation.Image(url: url))
//    }
//    
//    public init(id: Document.ID, url: URL, date: Date, specification: String, tags: Set<String>) {
//        self.id = id
//        self.url = url
//        self.date = date
//        self.specification = specification
//        self.tags = tags
//    }
//    
//    public init(document: Document) {
//        self.id = document.id
//        self.url = document.url
//        self.date = document.date
//        self.specification = document.specification
//        self.tags = document.tags
//    }
// }
//
// extension DocumentEntity: URLRepresentableEntity {
//    public static var urlRepresentation: URLRepresentation {
//        // ATTENTION: must be the same as DeepLink.document(123).url
//        "pdfarchiver://documents/\(.id)"
//    }
// }
//
//
// import AppIntents
//
//
//
// extension DocumentEntity: IndexedEntity {}
//
//
// import Dependencies
// import ArchiverStore
// import ArchiverModels
// import ComposableArchitecture
// import Shared
//
// public struct DocumentEntityQuery: EntityQuery {
//    
//    @Dependencies.Dependency(\.archiveStore) var archiveStore
//
//    public init() {}
//    
//    public func entities(for identifiers: [DocumentEntity.ID]) async throws -> [DocumentEntity] {
////        Logger.entityQueryLogging.debug("[DocumentEntityQuery] Query for IDs \(identifiers)")
//        
//        let identifiers = Set(identifiers)
//        
//        return try await archiveStore.getDocuments()
//            .filter { identifiers.contains($0.id) }
//            .map { DocumentEntity(document: $0) }
//    }
//    
//    public func suggestedEntities() async throws -> [DocumentEntity] {
////        Logger.entityQueryLogging.debug("[DocumentEntityQuery] Request for suggested entities")
//        
//        return try await archiveStore.getDocuments()
//            .sorted { $0.date > $1.date }
//            .prefix(20)
//            .map { DocumentEntity(document: $0) }
//    }
// }
//
// extension DocumentEntityQuery: EntityStringQuery {
//    public func entities(matching string: String) async throws -> [DocumentEntity] {
////        Logger.entityQueryLogging.debug("[DocumentEntityQuery] String query for term \(string)")
//        
//        return try await archiveStore.getDocuments()
//            .filter { $0.url.lastPathComponent.localizedCaseInsensitiveContains(string) }
//            .map { DocumentEntity(document: $0) }
//    }
// }
//
// func updateSpotlightIndex(with documents: [Document]) {
//    try! await CSSearchableIndex.default().deleteAllSearchableItems()
//    let items = documents.map { document in
//        let weight = document.isTagged ? 10 : 1
//        let item = CSSearchableItem(uniqueIdentifier: "\(document.id)",
//                                    domainIdentifier: nil,
//                                    attributeSet: document.searchableAttributes)
//        
//        let intent = DocumentEntity(document: document)
//        item.associateAppEntity(intent, priority: weight)
//        
//        return item
//        
//        //                                    return
//    }
//    try! await CSSearchableIndex.default().indexSearchableItems(items)
//    
//    print("CSSearchableIndex update complete")
// }
