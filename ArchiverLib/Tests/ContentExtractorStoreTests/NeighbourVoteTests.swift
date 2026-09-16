//
//  NeighbourVoteTests.swift
//  ContentExtractorStoreTests
//

import Foundation
import Testing

@testable import ContentExtractorStore

@Suite("NeighbourVote")
struct NeighbourVoteTests {

    @Test("A single neighbour's tags are copied")
    func aLoneNeighbourIsCopied() {
        let tags = NeighbourVote.widen(["alpha"], with: [neighbour(tags: ["beta"], rank: -100)])

        #expect(tags == ["alpha", "beta"])
    }

    @Test("A tag on three of five equally ranked neighbours is added, one on two is not")
    func theMajorityOfEqualNeighboursDecides() {
        let neighbours = [neighbour(tags: ["beta", "gamma"], rank: -100),
                          neighbour(tags: ["beta", "gamma"], rank: -100),
                          neighbour(tags: ["beta"], rank: -100),
                          neighbour(tags: [], rank: -100),
                          neighbour(tags: [], rank: -100)]

        let tags = NeighbourVote.widen(["alpha"], with: neighbours)

        #expect(tags == ["alpha", "beta"])
    }

    // The point of weighting: a far stronger match outvotes four weak ones, which a
    // plain 3-of-5 count would get backwards.
    @Test("The bm25 weight decides, not the neighbour count")
    func theStrongestMatchOutvotesFourWeakOnes() {
        let neighbours = [neighbour(tags: ["beta"], rank: -900),
                          neighbour(tags: ["gamma"], rank: -100),
                          neighbour(tags: ["gamma"], rank: -100),
                          neighbour(tags: ["gamma"], rank: -100),
                          neighbour(tags: ["gamma"], rank: -100)]

        let tags = NeighbourVote.widen(["alpha"], with: neighbours)

        #expect(tags == ["alpha", "beta"])
    }

    @Test("Model tags are kept and the cap holds")
    func theCapLeavesRoomForOneAddedTag() {
        let agreed = ["delta", "epsilon", "zeta"]
        let neighbours = [neighbour(tags: agreed, rank: -100), neighbour(tags: agreed, rank: -100)]

        let tags = NeighbourVote.widen(["alpha", "beta", "gamma"], with: neighbours)

        #expect(tags == ["alpha", "beta", "gamma", "delta"])
    }

    @Test("An empty model answer is filled from the neighbours")
    func anEmptyAnswerIsFilled() {
        let tags = NeighbourVote.widen([], with: [neighbour(tags: ["beta", "gamma"], rank: -100)])

        #expect(tags == ["beta", "gamma"])
    }

    @Test("A tag the model already suggested is not duplicated")
    func anAlreadySuggestedTagIsNotRepeated() {
        let tags = NeighbourVote.widen(["Beta"], with: [neighbour(tags: ["beta"], rank: -100)])

        #expect(tags == ["Beta"])
    }

    // A non-negative rank is a Vision distance from the visual fallback channel, whose
    // neighbours share a layout, not a filing convention.
    @Test("Visual neighbours never vote")
    func positiveRanksLeaveTheTagsUnchanged() {
        let tags = NeighbourVote.widen(["alpha"], with: [neighbour(tags: ["beta"], rank: 0.4)])

        #expect(tags == ["alpha"])
    }

    @Test("Without neighbours nothing changes")
    func noNeighboursLeaveTheTagsUnchanged() {
        #expect(NeighbourVote.widen(["alpha"], with: []) == ["alpha"])
    }

    @Test("Equal shares are ordered alphabetically")
    func tiesAreBrokenByName() {
        let tags = NeighbourVote.widen([], with: [neighbour(tags: ["gamma", "beta"], rank: -100)])

        #expect(tags == ["beta", "gamma"])
    }

    private func neighbour(tags: [String], rank: Double) -> NeighbourFinder.Match {
        NeighbourFinder.Match(date: Date(timeIntervalSince1970: 0), specification: "document", tags: tags, rank: rank)
    }
}
