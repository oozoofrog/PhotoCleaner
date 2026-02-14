//
//  KeywordLocalizationServiceTests.swift
//  PhotoCleanerTests
//

import Foundation
import Testing
@testable import PhotoCleaner

@Suite("KeywordLocalizationService Tests")
@MainActor
struct KeywordLocalizationServiceTests {
    private let service = KeywordLocalizationService()

    @Test("로케일이 한국어면 영어 키워드를 한글 키워드로 번역한다")
    func translatesEnglishKeywordToKoreanOnKoreanLocale() {
        #expect(
            service.localizedDisplayKeyword(
                from: "cat",
                sourceLanguageCode: "en",
                locale: Locale(identifier: "ko-KR")
            ) == "고양이"
        )
        #expect(
            service.localizedDisplayKeyword(
                from: "sunset",
                sourceLanguageCode: "en",
                locale: Locale(identifier: "ko-KR")
            ) == "일몰"
        )
    }

    @Test("로케일이 영어면 원문을 그대로 표시한다")
    func keepsKeywordWhenLocaleIsEnglish() {
        #expect(
            service.localizedDisplayKeyword(
                from: "cat",
                sourceLanguageCode: "en",
                locale: Locale(identifier: "en-US")
            ) == "cat"
        )
    }

    @Test("매핑이 없으면 원문을 fallback으로 사용한다")
    func fallsBackToOriginalWhenNoMappingExists() {
        #expect(
            service.localizedDisplayKeyword(
                from: "unknown-keyword",
                sourceLanguageCode: "en",
                locale: Locale(identifier: "ko-KR")
            ) == "unknown-keyword"
        )
    }
}
