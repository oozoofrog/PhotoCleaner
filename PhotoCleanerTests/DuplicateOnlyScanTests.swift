//
//  DuplicateOnlyScanTests.swift
//  PhotoCleanerTests
//
//  중복 사진만 검사 기능 테스트
//

import Testing
@testable import PhotoCleaner

@Suite("Duplicate Only Scan Tests")
struct DuplicateOnlyScanTests {

    @Test("중복 이슈 타입 확인")
    @MainActor
    func duplicateIssueTypeCheck() async throws {
        // Given - Preview 데이터 사용
        let issues = PreviewSampleData.duplicateIssues

        // Then
        // 모든 이슈가 중복 타입인지 확인
        for issue in issues {
            #expect(issue.issueType == .duplicate)
        }

        // 중복이 아닌 이슈가 없는지 확인
        let nonDuplicateIssues = issues.filter { $0.issueType != .duplicate }
        #expect(nonDuplicateIssues.isEmpty)
    }

    @Test("중복 그룹 계산이 정확함")
    @MainActor
    func duplicateGroupCalculationIsCorrect() async throws {
        // Given
        let groups = PreviewSampleData.duplicateGroups

        // Then
        #expect(groups.count == 2)

        // 첫 번째 그룹: 3개의 사진 (원본 1 + 중복 2)
        let firstGroup = groups[0]
        #expect(firstGroup.assetIdentifiers.count == 3)
        #expect(firstGroup.duplicateAssetIdentifiers.count == 2)

        // 두 번째 그룹: 2개의 사진 (원본 1 + 중복 1)
        let secondGroup = groups[1]
        #expect(secondGroup.assetIdentifiers.count == 2)
        #expect(secondGroup.duplicateAssetIdentifiers.count == 1)
    }

    @Test("ScanResult의 duplicateSummary 계산")
    @MainActor
    func scanResultDuplicateSummaryCalculation() async throws {
        // Given
        let result = PreviewSampleData.normalScanResult

        // When
        let summary = result.duplicateSummary

        // Then
        #expect(summary.groupCount == 2)
        #expect(summary.duplicateCount == 3) // (3-1) + (2-1) = 3
        #expect(summary.potentialSavings > 0)
    }

    @Test("빈 결과의 duplicateSummary는 0")
    @MainActor
    func emptyResultDuplicateSummaryIsZero() async throws {
        // Given
        let result = PreviewSampleData.emptyScanResult

        // When
        let summary = result.duplicateSummary

        // Then
        #expect(summary.groupCount == 0)
        #expect(summary.duplicateCount == 0)
        #expect(summary.potentialSavings == 0)
    }
}
