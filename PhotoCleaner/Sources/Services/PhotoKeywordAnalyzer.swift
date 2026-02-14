//
//  PhotoKeywordAnalyzer.swift
//  PhotoCleaner
//

import Foundation
import Photos
import Vision

struct PhotoKeywordAnalyzer: Sendable {
    static let defaultConfidenceThreshold = 0.8
    static let defaultMaxKeywordCount = 3

    struct RecognizedKeywordCandidate: Sendable {
        let keyword: String
        let confidence: Double
    }

    func extractKeywords(
        from asset: PHAsset,
        using photoAssetService: PhotoAssetService,
        languageCode: String = Locale.current.languageCode ?? "en",
        minimumConfidence: Double = defaultConfidenceThreshold,
        maxKeywordCount: Int = defaultMaxKeywordCount,
        createdAt: Date = Date()
    ) async -> [AssetKeywordDTO] {
        let candidates = await requestTextCandidates(
            from: asset,
            using: photoAssetService,
            languageCode: languageCode
        )

        return Self.buildKeywords(
            from: candidates,
            assetIdentifier: asset.localIdentifier,
            languageCode: languageCode,
            minimumConfidence: minimumConfidence,
            maxKeywordCount: maxKeywordCount,
            createdAt: createdAt,
            isEnabled: true
        )
    }

    static func buildKeywords(
        from candidates: [RecognizedKeywordCandidate],
        assetIdentifier: String,
        languageCode: String,
        minimumConfidence: Double,
        maxKeywordCount: Int,
        createdAt: Date,
        isEnabled: Bool = true
    ) -> [AssetKeywordDTO] {
        guard isEnabled, maxKeywordCount > 0 else { return [] }

        let threshold = Self.clampConfidence(minimumConfidence)
        let limit = max(1, maxKeywordCount)
        let sortedCandidates = candidates.sorted {
            if $0.confidence == $1.confidence {
                return $0.keyword < $1.keyword
            }
            return $0.confidence > $1.confidence
        }

        let filtered = sortedCandidates
            .compactMap { candidate -> [(String, Double)]? in
                guard candidate.confidence >= threshold else { return nil }
                let normalized = Self.normalizedKeywords(from: candidate.keyword)
                return normalized.map { ($0, candidate.confidence) }
            }
            .flatMap { $0 }

        var uniqueKeywords: [String: Double] = [:]
        for (keyword, confidence) in filtered where uniqueKeywords[keyword] == nil {
            uniqueKeywords[keyword] = confidence
        }

        return uniqueKeywords
            .map { (keyword, confidence) in
                AssetKeywordDTO(
                    assetIdentifier: assetIdentifier,
                    keyword: keyword,
                    confidence: confidence,
                    languageCode: languageCode,
                    createdAt: createdAt,
                    isManual: false
                )
            }
            .sorted {
                if $0.confidence == $1.confidence {
                    return $0.keyword < $1.keyword
                }
                return $0.confidence > $1.confidence
            }
            .prefix(limit)
            .map { $0 }
    }

    private func requestTextCandidates(
        from asset: PHAsset,
        using photoAssetService: PhotoAssetService,
        languageCode: String
    ) async -> [RecognizedKeywordCandidate] {
        let pointSize = CGSize(width: 320, height: 320)

        guard let (cgImage, _) = try? await photoAssetService.requestThumbnailCGImageForVision(
            for: asset,
            pointSize: pointSize,
            scale: 1.0
        ) else {
            return []
        }

        return await Task.detached {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .fast
            request.recognitionLanguages = [languageCode]

            let handler = VNImageRequestHandler(cgImage: cgImage)
            do {
                try handler.perform([request])
                guard let observations = request.results else { return [] }

                return observations
                    .compactMap { $0.topCandidates(1).first }
                    .map {
                        RecognizedKeywordCandidate(
                            keyword: $0.string,
                            confidence: Double($0.confidence)
                        )
                    }
            } catch {
                return []
            }
        }.value
    }

    private static func normalizedKeywords(from raw: String) -> [String] {
        let trimmed = raw
            .lowercased()
            .replacingOccurrences(of: "\\p{Punct}", with: "", options: .regularExpression)

        return trimmed
            .split { !$0.isLetter && !$0.isNumber }
            .map { String($0) }
            .filter { $0.count >= 2 }
    }

    private static func clampConfidence(_ value: Double) -> Double {
        min(max(value, 0.0), 1.0)
    }
}
