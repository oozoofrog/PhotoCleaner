//
//  ScanResultTests.swift
//  PhotoCleanerTests
//
//  ScanResult 및 관련 타입에 대한 테스트
//

import Foundation
import Testing
@testable import PhotoCleaner

@Suite("ScanResult Tests")
@MainActor
struct ScanResultTests {

    // MARK: - Basic Tests

    @Test("빈 issues 배열로 ScanResult 생성")
    func emptyScanResult() async throws {
        let result = ScanResult(
            totalPhotos: 0,
            issues: [],
            summaries: [],
            scannedAt: Date()
        )

        #expect(result.totalPhotos == 0)
        #expect(result.issues.isEmpty)
        #expect(result.summaries.isEmpty)
        #expect(result.totalIssueCount == 0)
    }

    @Test("totalIssueCount는 issues.count와 동일")
    func totalIssueCountEqualsIssuesCount() async throws {
        // 빈 배열
        let emptyResult = ScanResult(
            totalPhotos: 0,
            issues: [],
            summaries: [],
            scannedAt: Date()
        )
        #expect(emptyResult.totalIssueCount == emptyResult.issues.count)
    }

    // MARK: - issues(for:) Tests

    @Test("issues(for:) 필터링이 정확함")
    func issuesForTypeFiltering() async throws {
        // 모든 IssueType에 대해 빈 결과 반환 검증
        let emptyResult = ScanResult(
            totalPhotos: 100,
            issues: [],
            summaries: [],
            scannedAt: Date()
        )

        for issueType in IssueType.allCases {
            let filtered = emptyResult.issues(for: issueType)
            #expect(filtered.isEmpty)
        }
    }

    // MARK: - summary(for:) Tests

    @Test("summary(for:) 빈 summaries에서 nil 반환")
    func summaryForTypeReturnsNil() async throws {
        let result = ScanResult(
            totalPhotos: 100,
            issues: [],
            summaries: [],
            scannedAt: Date()
        )

        for issueType in IssueType.allCases {
            #expect(result.summary(for: issueType) == nil)
        }
    }

    @Test("summary(for:) 존재하는 타입에 대해 올바른 요약 반환")
    func summaryForTypeReturnsCorrect() async throws {
        let summaries = [
            IssueSummary(issueType: IssueType.screenshot, count: 10, totalSize: 1024 * 1024),
            IssueSummary(issueType: IssueType.largeFile, count: 5, totalSize: 50 * 1024 * 1024)
        ]

        let result = ScanResult(
            totalPhotos: 100,
            issues: [],
            summaries: summaries,
            scannedAt: Date()
        )

        let screenshotSummary = result.summary(for: IssueType.screenshot)
        #expect(screenshotSummary?.count == 10)
        #expect(screenshotSummary?.issueType == IssueType.screenshot)

        let largeFileSummary = result.summary(for: IssueType.largeFile)
        #expect(largeFileSummary?.count == 5)

        // 없는 타입
        #expect(result.summary(for: IssueType.duplicate) == nil)
    }
}

// MARK: - ScanProgress Tests

@Suite("ScanProgress Tests")
@MainActor
struct ScanProgressTests {

    @Test("progress 계산이 정확함")
    func progressCalculation() async throws {
        let progress1 = ScanProgress(phase: .scanning, current: 50, total: 100)
        #expect(progress1.progress == 0.5)

        let progress2 = ScanProgress(phase: .scanning, current: 0, total: 100)
        #expect(progress2.progress == 0.0)

        let progress3 = ScanProgress(phase: .completed, current: 100, total: 100)
        #expect(progress3.progress == 1.0)
    }

    @Test("total이 0일 때 progress는 0")
    func progressZeroWhenTotalZero() async throws {
        let progress = ScanProgress(phase: .preparing, current: 0, total: 0)
        #expect(progress.progress == 0)
    }

    @Test("displayText가 phase에 따라 올바름")
    func displayTextMatchesPhase() async throws {
        let preparing = ScanProgress(phase: .preparing, current: 0, total: 0)
        #expect(preparing.displayText == "준비 중...")

        let scanning = ScanProgress(phase: .scanning, current: 50, total: 100)
        #expect(scanning.displayText == "50/100 검사 중...")

        let completed = ScanProgress(phase: .completed, current: 100, total: 100)
        #expect(completed.displayText == "검사 완료")

        let failed = ScanProgress(phase: .failed, current: 0, total: 0)
        #expect(failed.displayText == "검사 실패")
    }

    // MARK: - Random Data Tests

    @Test("progress는 유효한 범위 내", arguments: [(0, 100), (50, 100), (100, 100), (0, 0)])
    func progressInValidRange(current: Int, total: Int) async throws {
        let progress = ScanProgress(
            phase: .scanning,
            current: current,
            total: total
        )

        #expect(progress.progress >= 0)
        if total > 0 {
            #expect(progress.progress <= 1.0)
        }
    }
}

// MARK: - IssueSummary Tests

@Suite("IssueSummary Tests")
@MainActor
struct IssueSummaryTests {

    @Test("IssueSummary id는 issueType.id와 동일")
    func issueSummaryIdMatchesIssueType() async throws {
        for issueType in IssueType.allCases {
            let summary = IssueSummary(
                issueType: issueType,
                count: 1,
                totalSize: 0
            )
            #expect(summary.id == issueType.id)
        }
    }

    @Test("formattedTotalSize 형식 검증")
    func formattedTotalSizeFormat() async throws {
        // 1 KB
        let summary1KB = IssueSummary(issueType: .screenshot, count: 1, totalSize: 1024)
        #expect(!summary1KB.formattedTotalSize.isEmpty)

        // 1 MB
        let summary1MB = IssueSummary(issueType: .largeFile, count: 1, totalSize: 1024 * 1024)
        #expect(!summary1MB.formattedTotalSize.isEmpty)

        // 0 bytes
        let summary0 = IssueSummary(issueType: .duplicate, count: 0, totalSize: 0)
        #expect(!summary0.formattedTotalSize.isEmpty)
    }

    // MARK: - Random Data Tests

    @Test("다양한 totalSize에 대해 formattedTotalSize가 crash하지 않음", arguments: [Int64(0), Int64(1024), Int64(1024 * 1024), Int64(1024 * 1024 * 1024)])
    func formattedTotalSizeNeverCrashes(size: Int64) async throws {
        let issueType = TestDataGenerator.randomIssueType()
        let summary = IssueSummary(
            issueType: issueType,
            count: 1,
            totalSize: size
        )
        _ = summary.formattedTotalSize
        // 크래시 없이 완료되면 성공
    }
}
