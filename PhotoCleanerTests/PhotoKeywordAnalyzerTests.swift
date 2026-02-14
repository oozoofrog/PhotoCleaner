//
//  PhotoKeywordAnalyzerTests.swift
//  PhotoCleanerTests
//

import Foundation
import Testing
@testable import PhotoCleaner

@Suite("PhotoKeywordAnalyzer Tests")
@MainActor
struct PhotoKeywordAnalyzerTests {
    @Test("임계값 미만 후보는 제외된다")
    func filtersBelowThreshold() {
        let candidates: [PhotoKeywordAnalyzer.RecognizedKeywordCandidate] = [
            .init(keyword: "apple", confidence: 0.79),
            .init(keyword: "banana", confidence: 0.81),
            .init(keyword: "cat", confidence: 0.8)
        ]

        let keywords = PhotoKeywordAnalyzer.buildKeywords(
            from: candidates,
            assetIdentifier: "asset-1",
            languageCode: "en",
            minimumConfidence: 0.8,
            maxKeywordCount: 3,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            isEnabled: true
        )

        #expect(keywords.count == 2)
        #expect(keywords.contains { $0.keyword == "banana" })
        #expect(keywords.contains { $0.keyword == "cat" })
    }

    @Test("상위 3개까지만 반환하고 신뢰도 순으로 정렬한다")
    func keepsTopThreeKeywordsSorted() {
        let candidates: [PhotoKeywordAnalyzer.RecognizedKeywordCandidate] = [
            .init(keyword: "small dog", confidence: 0.79),
            .init(keyword: "강아지", confidence: 0.99),
            .init(keyword: "sunset scene", confidence: 0.95),
            .init(keyword: "cat", confidence: 0.98),
            .init(keyword: "bird", confidence: 0.88),
            .init(keyword: "mountain", confidence: 0.85)
        ]

        let keywords = PhotoKeywordAnalyzer.buildKeywords(
            from: candidates,
            assetIdentifier: "asset-1",
            languageCode: "en",
            minimumConfidence: 0.8,
            maxKeywordCount: 3,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            isEnabled: true
        )

        #expect(keywords.count == 3)
        #expect(keywords.map(\.keyword) == ["강아지", "cat", "scene"])
    }

    @Test("비활성화하면 키워드 분석 결과가 비어 있다")
    func disabledReturnsNoKeywords() {
        let candidates: [PhotoKeywordAnalyzer.RecognizedKeywordCandidate] = [
            .init(keyword: "cat", confidence: 0.99)
        ]

        let keywords = PhotoKeywordAnalyzer.buildKeywords(
            from: candidates,
            assetIdentifier: "asset-1",
            languageCode: "en",
            minimumConfidence: 0.8,
            maxKeywordCount: 3,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            isEnabled: false
        )

        #expect(keywords.isEmpty)
    }
}
