//
//  AppSettings.swift
//  PhotoCleaner
//

import SwiftUI

enum DuplicateDetectionMode: String, CaseIterable, Identifiable {
    case exactOnly = "exactOnly"
    case includeSimilar = "includeSimilar"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .exactOnly: "완전 동일만"
        case .includeSimilar: "유사 포함"
        }
    }
}

enum SimilarityThreshold: Int, CaseIterable, Identifiable {
    case percent80 = 80
    case percent90 = 90
    case percent95 = 95

    var id: Int { rawValue }

    var displayName: String { "\(rawValue)%" }

    var floatValue: Float { Float(rawValue) / 100.0 }
}

enum ThumbnailSize: String, CaseIterable, Identifiable {
    case small = "small"
    case medium = "medium"
    case large = "large"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small: "작게"
        case .medium: "보통"
        case .large: "크게"
        }
    }

    var rowHeight: CGFloat {
        switch self {
        case .small: 80
        case .medium: 120
        case .large: 160
        }
    }
}

enum SortOrder: String, CaseIterable, Identifiable {
    case date = "date"
    case size = "size"
    case name = "name"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .date: "날짜"
        case .size: "크기"
        case .name: "이름"
        }
    }
}

@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let largeFileSizeOption = "largeFileSizeOption"
        static let duplicateDetectionMode = "duplicateDetectionMode"
        static let similarityThreshold = "similarityThreshold"
        static let autoScanEnabled = "autoScanEnabled"
        static let thumbnailSize = "thumbnailSize"
        static let sortOrder = "sortOrder"
    }

    var largeFileSizeOption: LargeFileSizeOption {
        didSet { defaults.set(largeFileSizeOption.rawValue, forKey: Keys.largeFileSizeOption) }
    }

    var duplicateDetectionMode: DuplicateDetectionMode {
        didSet { defaults.set(duplicateDetectionMode.rawValue, forKey: Keys.duplicateDetectionMode) }
    }

    var similarityThreshold: SimilarityThreshold {
        didSet { defaults.set(similarityThreshold.rawValue, forKey: Keys.similarityThreshold) }
    }

    var autoScanEnabled: Bool {
        didSet { defaults.set(autoScanEnabled, forKey: Keys.autoScanEnabled) }
    }

    var thumbnailSize: ThumbnailSize {
        didSet { defaults.set(thumbnailSize.rawValue, forKey: Keys.thumbnailSize) }
    }

    var sortOrder: SortOrder {
        didSet { defaults.set(sortOrder.rawValue, forKey: Keys.sortOrder) }
    }

    private init() {
        let storedLargeFileSize = defaults.string(forKey: Keys.largeFileSizeOption)
        self.largeFileSizeOption = LargeFileSizeOption(rawValue: storedLargeFileSize ?? "") ?? .mb10

        let storedDuplicateMode = defaults.string(forKey: Keys.duplicateDetectionMode)
        self.duplicateDetectionMode = DuplicateDetectionMode(rawValue: storedDuplicateMode ?? "") ?? .includeSimilar

        let storedSimilarity = defaults.integer(forKey: Keys.similarityThreshold)
        self.similarityThreshold = SimilarityThreshold(rawValue: storedSimilarity) ?? .percent95

        self.autoScanEnabled = defaults.bool(forKey: Keys.autoScanEnabled)

        let storedThumbnailSize = defaults.string(forKey: Keys.thumbnailSize)
        self.thumbnailSize = ThumbnailSize(rawValue: storedThumbnailSize ?? "") ?? .medium

        let storedSortOrder = defaults.string(forKey: Keys.sortOrder)
        self.sortOrder = SortOrder(rawValue: storedSortOrder ?? "") ?? .date
    }

    func resetToDefaults() {
        largeFileSizeOption = .mb10
        duplicateDetectionMode = .includeSimilar
        similarityThreshold = .percent95
        autoScanEnabled = false
        thumbnailSize = .medium
        sortOrder = .date
    }
}
