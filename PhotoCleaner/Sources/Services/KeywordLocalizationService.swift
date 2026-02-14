//
//  KeywordLocalizationService.swift
//  PhotoCleaner
//

import Foundation

struct KeywordLocalizationService: Sendable {
    private static let englishToKoreanMap: [String: String] = [
        "cat": "고양이",
        "dog": "개",
        "sunset": "일몰",
        "bird": "새",
        "flower": "꽃",
        "tree": "나무",
        "mountain": "산",
        "beach": "해변",
        "people": "사람",
        "building": "건물",
        "car": "차량",
        "coffee": "커피",
        "water": "물",
        "road": "도로"
    ]

    func localizedDisplayKeyword(
        from keyword: String,
        sourceLanguageCode: String = "en",
        locale: Locale = .current
    ) -> String {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return keyword }

        let normalizedKeyword = trimmed.lowercased()
        let normalizedSourceLanguage = sourceLanguageCode.lowercased()

        if normalizedSourceLanguage == "ko" {
            return trimmed
        }

        guard isKorean(locale: locale) else { return trimmed }
        return Self.englishToKoreanMap[normalizedKeyword] ?? trimmed
    }

    func isKorean(locale: Locale = .current) -> Bool {
        guard let languageCode = locale.languageCode?.lowercased() else { return false }
        return languageCode == "ko"
    }
}
