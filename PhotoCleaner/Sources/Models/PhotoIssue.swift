//
//  PhotoIssue.swift
//  PhotoCleaner
//
//  문제가 있는 사진을 나타내는 데이터 모델
//

import Photos
import SwiftUI

/// 문제 유형
enum IssueType: String, CaseIterable, Identifiable, Sendable {
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
    @MainActor var color: Color {
        switch self {
        case .downloadFailed: AppColor.warning
        case .corrupted: AppColor.destructive
        case .screenshot: AppColor.primary
        case .largeFile: AppColor.secondary
        case .duplicate: AppColor.primary
        }
    }

    /// 사용자용 상세 설명
    var userDescription: String {
        switch self {
        case .downloadFailed:
            return "iCloud에만 저장된 사진입니다. 설정 > 사진에서 '원본 다운로드'를 선택하세요."
        case .corrupted:
            return "사진 파일이 손상되었거나 읽을 수 없습니다."
        case .screenshot:
            return "스크린샷은 저장 공간을 차지합니다. 불필요한 것은 삭제하세요."
        case .largeFile:
            return "10MB 이상의 대용량 파일입니다."
        case .duplicate:
            return "동일하거나 유사한 사진이 여러 장 있습니다."
        }
    }

    /// 심각도 기본값
    nonisolated var defaultSeverity: IssueSeverity {
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
enum IssueSeverity: Int, Comparable, Sendable {
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

    @MainActor var color: Color {
        switch self {
        case .info: AppColor.secondary
        case .warning: AppColor.warning
        case .critical: AppColor.destructive
        }
    }
}

/// 문제 사진 모델
struct PhotoIssue: Identifiable, Hashable, Sendable {
    let id: String
    let assetIdentifier: String
    let issueType: IssueType
    let severity: IssueSeverity
    let detectedAt: Date
    let metadata: IssueMetadata
    let aspectRatio: CGFloat  // width / height (자연 비율 그리드용)

    nonisolated init(
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
        self.aspectRatio = asset.pixelHeight > 0
            ? CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
            : 1.0
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: PhotoIssue, rhs: PhotoIssue) -> Bool {
        lhs.id == rhs.id
    }
}

/// 문제 관련 메타데이터
struct IssueMetadata: Hashable, Sendable {
    var fileSize: Int64?            // 파일 크기 (bytes)
    var errorMessage: String?       // 에러 메시지
    var duplicateGroupId: String?   // 중복 그룹 ID
    var canRecover: Bool = false    // 복구 가능 여부

    nonisolated init(
        fileSize: Int64? = nil,
        errorMessage: String? = nil,
        duplicateGroupId: String? = nil,
        canRecover: Bool = false
    ) {
        self.fileSize = fileSize
        self.errorMessage = errorMessage
        self.duplicateGroupId = duplicateGroupId
        self.canRecover = canRecover
    }

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

struct DuplicateGroup: Identifiable, Sendable {
    let id: String
    let assetIdentifiers: [String]
    let suggestedOriginalId: String
    let similarity: Double
    let potentialSavings: Int64

    var count: Int { assetIdentifiers.count }

    var formattedSavings: String {
        ByteCountFormatter.string(fromByteCount: potentialSavings, countStyle: .file)
    }
    
    func isOriginal(_ assetId: String) -> Bool {
        assetId == suggestedOriginalId
    }
    
    var isExactDuplicate: Bool {
        similarity >= 1.0
    }
    
    var duplicateAssetIdentifiers: [String] {
        assetIdentifiers.filter { $0 != suggestedOriginalId }
    }
    
    var similarityLabel: String {
        if isExactDuplicate {
            return "완전 동일"
        }
        let percent = Int(similarity * 100)
        return "\(percent)% 유사"
    }
}

enum LargeFileSizeOption: Int64, CaseIterable, Identifiable {
    case mb5 = 5_242_880
    case mb10 = 10_485_760
    case mb25 = 26_214_400
    case mb50 = 52_428_800
    case mb100 = 104_857_600

    var id: Int64 { rawValue }

    var displayName: String {
        switch self {
        case .mb5: "5 MB"
        case .mb10: "10 MB"
        case .mb25: "25 MB"
        case .mb50: "50 MB"
        case .mb100: "100 MB"
        }
    }

    var bytes: Int64 { rawValue }
}
