//
//  DuplicateDetectionTests.swift
//  PhotoCleanerTests
//

import Foundation
import Testing
@testable import PhotoCleaner

@Suite("DuplicateGroup Tests")
@MainActor
struct DuplicateGroupTests {

    @Test("DuplicateGroup count는 assetIdentifiers.count와 동일")
    func countEqualsAssetIdentifiersCount() async throws {
        let group = DuplicateGroup(
            id: "test-group",
            assetIdentifiers: ["asset1", "asset2", "asset3"],
            suggestedOriginalId: "asset1",
            similarity: 1.0,
            potentialSavings: 1024
        )

        #expect(group.count == 3)
        #expect(group.count == group.assetIdentifiers.count)
    }

    @Test("formattedSavings가 올바른 형식")
    func formattedSavingsFormat() async throws {
        let group1MB = DuplicateGroup(
            id: "test",
            assetIdentifiers: ["a", "b"],
            suggestedOriginalId: "a",
            similarity: 1.0,
            potentialSavings: 1024 * 1024
        )

        #expect(!group1MB.formattedSavings.isEmpty)
    }

    @Test("빈 그룹에서 count는 0")
    func emptyGroupHasZeroCount() async throws {
        let group = DuplicateGroup(
            id: "empty",
            assetIdentifiers: [],
            suggestedOriginalId: "",
            similarity: 1.0,
            potentialSavings: 0
        )

        #expect(group.count == 0)
    }
}

@Suite("ScanResult Duplicate Tests")
@MainActor
struct ScanResultDuplicateTests {

    @Test("duplicateSummary 계산이 정확함")
    func duplicateSummaryCalculation() async throws {
        let groups = [
            DuplicateGroup(
                id: "group1",
                assetIdentifiers: ["a", "b", "c"],
                suggestedOriginalId: "a",
                similarity: 1.0,
                potentialSavings: 1000
            ),
            DuplicateGroup(
                id: "group2",
                assetIdentifiers: ["d", "e"],
                suggestedOriginalId: "d",
                similarity: 1.0,
                potentialSavings: 500
            )
        ]

        let result = ScanResult(
            totalPhotos: 100,
            issues: [],
            summaries: [],
            duplicateGroups: groups,
            scannedAt: Date()
        )

        let summary = result.duplicateSummary
        #expect(summary.groupCount == 2)
        #expect(summary.duplicateCount == 3)
        #expect(summary.potentialSavings == 1500)
    }

    @Test("빈 duplicateGroups에서 duplicateSummary는 모두 0")
    func emptyDuplicateGroupsHasZeroSummary() async throws {
        let result = ScanResult(
            totalPhotos: 100,
            issues: [],
            summaries: [],
            duplicateGroups: [],
            scannedAt: Date()
        )

        let summary = result.duplicateSummary
        #expect(summary.groupCount == 0)
        #expect(summary.duplicateCount == 0)
        #expect(summary.potentialSavings == 0)
    }

    @Test("duplicateCount는 원본을 제외한 수")
    func duplicateCountExcludesOriginal() async throws {
        let group = DuplicateGroup(
            id: "test",
            assetIdentifiers: ["original", "dup1", "dup2", "dup3"],
            suggestedOriginalId: "original",
            similarity: 1.0,
            potentialSavings: 3000
        )

        let result = ScanResult(
            totalPhotos: 10,
            issues: [],
            summaries: [],
            duplicateGroups: [group],
            scannedAt: Date()
        )

        #expect(result.duplicateSummary.duplicateCount == 3)
    }
}

@Suite("DuplicateGroup ID Tests")
@MainActor
struct DuplicateGroupIDTests {

    @Test("DuplicateGroup은 Identifiable")
    func duplicateGroupIsIdentifiable() async throws {
        let group1 = DuplicateGroup(
            id: "group-a",
            assetIdentifiers: ["x"],
            suggestedOriginalId: "x",
            similarity: 1.0,
            potentialSavings: 0
        )

        let group2 = DuplicateGroup(
            id: "group-b",
            assetIdentifiers: ["y"],
            suggestedOriginalId: "y",
            similarity: 1.0,
            potentialSavings: 0
        )

        #expect(group1.id != group2.id)
    }
}
