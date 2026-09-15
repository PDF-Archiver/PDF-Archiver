//
//  TagExpansionTests.swift
//  ContentExtractorStoreTests
//

import ArchiverModels
import Testing

@testable import ContentExtractorStore

@Suite("TagExpansion")
struct TagExpansionTests {

    private let archive = [
        Document.mock(tags: ["gehalt", "nlbv", "vanessa"]),
        Document.mock(tags: ["gehalt", "nlbv", "vanessa"]),
        Document.mock(tags: ["rechnung", "haus"])
    ]

    @Test("A tag co-occurring with a suggestion and named in the document is added")
    func addsCooccurringTagPresentInText() {
        let tags = TagExpansion.expanded(["gehalt"],
                                         with: archive,
                                         text: "Gehaltsmitteilung NLBV für Vanessa",
                                         limit: 4)

        // Only one tag is ever added, and `nlbv` wins the count tie by name.
        #expect(tags == ["gehalt", "nlbv"])
    }

    // A tag filed next to only *some* of the suggestions is right well below the model's
    // own precision, so it must not be offered.
    @Test("A tag missing from one of the suggested tags' documents is not added")
    func requiresEverySuggestedTag() {
        let archive = [Document.mock(tags: ["gehalt", "nlbv"]),
                       Document.mock(tags: ["gehalt", "nlbv"]),
                       Document.mock(tags: ["rechnung", "vanessa"])]

        let tags = TagExpansion.expanded(["gehalt", "rechnung"],
                                         with: archive,
                                         text: "Gehalt Rechnung NLBV Vanessa",
                                         limit: 4)

        #expect(tags == ["gehalt", "rechnung"])
    }

    @Test("A co-occurring tag the document never names is not added")
    func skipsCooccurringTagMissingFromText() {
        let tags = TagExpansion.expanded(["gehalt"],
                                         with: archive,
                                         text: "Gehaltsmitteilung August",
                                         limit: 4)

        #expect(tags == ["gehalt"])
    }

    @Test("A tag that never co-occurs with the suggestion is not added")
    func skipsUnrelatedTag() {
        let tags = TagExpansion.expanded(["gehalt"],
                                         with: archive,
                                         text: "Gehaltsmitteilung Rechnung Haus",
                                         limit: 4)

        #expect(tags == ["gehalt"])
    }

    @Test("Expansion stops at the limit")
    func respectsLimit() {
        let tags = TagExpansion.expanded(["gehalt"],
                                         with: archive,
                                         text: "Gehaltsmitteilung NLBV für Vanessa",
                                         limit: 2)

        #expect(tags == ["gehalt", "nlbv"])
    }

    @Test("Without a suggested tag there is nothing to expand from")
    func emptySuggestionStaysEmpty() {
        let tags = TagExpansion.expanded([],
                                         with: archive,
                                         text: "Gehaltsmitteilung NLBV für Vanessa",
                                         limit: 4)

        #expect(tags.isEmpty)
    }

    @Test("A candidate that was already suggested is not duplicated")
    func doesNotDuplicateSuggestions() {
        let tags = TagExpansion.expanded(["gehalt", "nlbv"],
                                         with: archive,
                                         text: "Gehaltsmitteilung NLBV für Vanessa",
                                         limit: 4)

        #expect(tags == ["gehalt", "nlbv", "vanessa"])
    }

    // Tags are slugified, the document text is not: without folding, a tag would
    // never match the spelling the document actually uses.
    @Test("Diacritics in the document text still match a slugified tag")
    func matchesSlugifiedText() {
        let archive = [Document.mock(tags: ["lampe", "nymane"]),
                       Document.mock(tags: ["lampe", "nymane"])]

        let tags = TagExpansion.expanded(["lampe"],
                                         with: archive,
                                         text: "NYMÅNE Deckenspot",
                                         limit: 4)

        #expect(tags == ["lampe", "nymane"])
    }

    @Test("A document word only containing the tag does not count as naming it")
    func requiresAWholeWord() {
        let archive = [Document.mock(tags: ["rechnung", "haus"]),
                       Document.mock(tags: ["rechnung", "haus"])]

        let tags = TagExpansion.expanded(["rechnung"],
                                         with: archive,
                                         text: "Rechnung für das Hausratversicherungspaket",
                                         limit: 4)

        #expect(tags == ["rechnung"])
    }
}
