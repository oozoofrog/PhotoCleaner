//
//  PhotoIssue.swift
//  PhotoCleaner
//
//  문제가 있는 사진을 나타내는 데이터 모델
//

import Photos
import SwiftUI

/// 문제 유형
enum IssueType: String, CaseIterable, Identifiable {
    case downloadFailed = "downloadFailed"  // iCloud 다운로드 실패
    case corrupted = "corrupted"            // 손상됨
    case screenshot = "screenshot"          // 스크린샷
    case largeFile = "largeFile"            // 대용량 파일
    case duplicate = "duplicate"            // 중복

    var id: String { rawValue }

    /// 표시 이름
    var displayName: String {
        switch self {
        case .downloadFailed: "다운로드 실패"
        case .corrupted: "손상됨"
        case .screenshot: "스크린샷"
        case .largeFile: "대용량"
        case .duplicate: "중복"
        }
    }

    /// SF Symbol 아이콘 이름
    var iconName: String {
        switch self {
        case .downloadFailed: "exclamationmark.icloud"
        case .corrupted: "exclamationmark.triangle"
        case .screenshot: "rectangle.on.rectangle"
        case .largeFile: "externaldrive"
        case .duplicate: "square.on.square"
        }
    }

    /// 테마 색상 (AppColor 토큰 사용)
    var color: Color {
        switch self {
        case .downloadFailed: AppColor.warning
        case .corrupted: AppColor.destructive
        case .screenshot: AppColor.primary
        case .largeFile: AppColor.secondary
        case .duplicate: AppColor.primary
        }
    }

    /// 심각도 기본값
    var defaultSeverity: IssueSeverity {
        switch self {
        case .downloadFailed: .warning
        case .corrupted: .critical
        case .screenshot: .info
        case .largeFile: .info
        case .duplicate: .info
        }
    }
}

/// 문제 심각도
enum IssueSeverity: Int, Comparable {
    case info = 0       // 정보성
    case warning = 1    // 주의 필요
    case critical = 2   // 즉시 조치 필요

    static func < (lhs: IssueSeverity, rhs: IssueSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .info: "정보"
        case .warning: "주의"
        case .critical: "심각"
        }
    }

    var color: Color {
        switch self {
        case .info: AppColor.secondary
        case .warning: AppColor.warning
        case .critical: AppColor.destructive
        }
    }
}

/// 문제 사진 모델
struct PhotoIssue: Identifiable, Hashable {
    let id: String
    let assetIdentifier: String
    let issueType: IssueType
    let severity: IssueSeverity
    let detectedAt: Date
    let metadata: IssueMetadata

    init(
        asset: PHAsset,
        issueType: IssueType,
        severity: IssueSeverity? = nil,
        metadata: IssueMetadata = IssueMetadata()
    ) {
        self.id = "\(asset.localIdentifier)-\(issueType.rawValue)"
        self.assetIdentifier = asset.localIdentifier
        self.issueType = issueType
        self.severity = severity ?? issueType.defaultSeverity
        self.detectedAt = Date()
        self.metadata = metadata
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: PhotoIssue, rhs: PhotoIssue) -> Bool {
        lhs.id == rhs.id
    }
}

/// 문제 관련 메타데이터
struct IssueMetadata: Hashable {
    var fileSize: Int64?            // 파일 크기 (bytes)
    var errorMessage: String?       // 에러 메시지
    var duplicateGroupId: String?   // 중복 그룹 ID
    var canRecover: Bool = false    // 복구 가능 여부

    /// 파일 크기를 사람이 읽기 쉬운 형식으로
    var formattedFileSize: String? {
        guard let size = fileSize else { return nil }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

/// 문제 유형별 요약 정보
struct IssueSummary: Identifiable {
    let issueType: IssueType
    var count: Int
    var totalSize: Int64

    var id: String { issueType.id }

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

/// 중복 그룹
struct DuplicateGroup: Identifiable {
    let id: String
    let assetIdentifiers: [String]
    let suggestedOriginalId: String
    let similarity: Double          // 0.0 ~ 1.0
    let potentialSavings: Int64     // 절약 가능 용량 (bytes)

    var count: Int { assetIdentifiers.count }

    var formattedSavings: String {
        ByteCountFormatter.string(fromByteCount: potentialSavings, countStyle: .file)
    }
}
