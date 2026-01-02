//
//  PhotoScanService.swift
//  PhotoCleaner
//
//  사진첩 스캔 및 문제 감지 서비스
//

import Photos
import UIKit

/// 스캔 진행 상태
struct ScanProgress: Sendable {
    var phase: ScanPhase
    var current: Int
    var total: Int
    var currentIssueType: IssueType?

    var progress: Double {
        guard total > 0 else { return 0 }
        return Double(current) / Double(total)
    }

    var displayText: String {
        switch phase {
        case .preparing: "준비 중..."
        case .scanning: "\(current)/\(total) 검사 중..."
        case .completed: "검사 완료"
        case .failed: "검사 실패"
        }
    }
}

enum ScanPhase: Sendable {
    case preparing
    case scanning
    case completed
    case failed
}

/// 스캔 결과
struct ScanResult {
    let totalPhotos: Int
    let issues: [PhotoIssue]
    let summaries: [IssueSummary]
    let scannedAt: Date

    var totalIssueCount: Int {
        issues.count
    }

    func issues(for type: IssueType) -> [PhotoIssue] {
        issues.filter { $0.issueType == type }
    }

    func summary(for type: IssueType) -> IssueSummary? {
        summaries.first { $0.issueType == type }
    }
}

/// 사진 스캔 서비스
actor PhotoScanService {

    // MARK: - Constants

    /// 진행률 업데이트 간격 (항목 수)
    private nonisolated static let progressUpdateInterval: Int = 100
    /// 대용량 파일 기준 (bytes) - 10MB
    private nonisolated static let largeFileThreshold: Int64 = 10 * 1024 * 1024
    /// 진행률 업데이트 최소 시간 간격 (초)
    private nonisolated static let progressDebounceInterval: TimeInterval = 0.1

    // MARK: - Properties

    private var cachedResult: ScanResult?
    private var lastProgressUpdate: Date = .distantPast

    // MARK: - Public Methods

    /// 전체 스캔 수행
    func scanAll(
        progressHandler: @escaping @MainActor @Sendable (ScanProgress) -> Void
    ) async throws -> ScanResult {
        // 준비 단계
        await progressHandler(ScanProgress(phase: .preparing, current: 0, total: 0))

        // 모든 사진 가져오기
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let allAssets = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        let total = allAssets.count
        var issues: [PhotoIssue] = []

        // 스캔 시작 - 비동기 처리로 변경
        let assets = convertToArray(allAssets)

        for (index, asset) in assets.enumerated() {
            // 진행률 업데이트 (debouncing 적용)
            if shouldUpdateProgress(index: index) {
                let progress = ScanProgress(phase: .scanning, current: index + 1, total: total)
                await progressHandler(progress)
            }

            // 문제 감지 (동기 - 이미지 로드 없이 메타데이터만 확인)
            let detectedIssues = detectIssues(for: asset)
            issues.append(contentsOf: detectedIssues)
        }

        // 요약 생성
        let summaries = createSummaries(from: issues)

        let result = ScanResult(
            totalPhotos: total,
            issues: issues,
            summaries: summaries,
            scannedAt: Date()
        )

        cachedResult = result

        // 완료
        await progressHandler(ScanProgress(phase: .completed, current: total, total: total))

        return result
    }

    /// 특정 유형만 스캔
    func scan(
        for issueTypes: [IssueType],
        progressHandler: @escaping @MainActor @Sendable (ScanProgress) -> Void
    ) async throws -> ScanResult {
        await progressHandler(ScanProgress(phase: .preparing, current: 0, total: 0))

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        // 스크린샷만 스캔할 경우 최적화
        if issueTypes == [.screenshot] {
            fetchOptions.predicate = NSPredicate(
                format: "(mediaSubtypes & %d) != 0",
                PHAssetMediaSubtype.photoScreenshot.rawValue
            )
        }

        let allAssets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        let total = allAssets.count
        var issues: [PhotoIssue] = []

        let assets = convertToArray(allAssets)

        for (index, asset) in assets.enumerated() {
            if shouldUpdateProgress(index: index) {
                let progress = ScanProgress(phase: .scanning, current: index + 1, total: total)
                await progressHandler(progress)
            }

            // 문제 감지 (동기 - 이미지 로드 없이 메타데이터만 확인)
            let detectedIssues = detectIssues(for: asset, types: issueTypes)
            issues.append(contentsOf: detectedIssues)
        }

        let summaries = createSummaries(from: issues)

        let result = ScanResult(
            totalPhotos: total,
            issues: issues,
            summaries: summaries,
            scannedAt: Date()
        )

        await progressHandler(ScanProgress(phase: .completed, current: total, total: total))

        return result
    }

    /// 캐시된 결과 가져오기
    func getCachedResult() -> ScanResult? {
        cachedResult
    }

    /// 캐시 초기화
    func clearCache() {
        cachedResult = nil
    }

    // MARK: - Progress Debouncing

    /// 진행률 업데이트 필요 여부 (debouncing)
    private func shouldUpdateProgress(index: Int) -> Bool {
        guard index % Self.progressUpdateInterval == 0 else { return false }

        let now = Date()
        if now.timeIntervalSince(lastProgressUpdate) >= Self.progressDebounceInterval {
            lastProgressUpdate = now
            return true
        }
        return false
    }

    /// PHFetchResult를 배열로 변환 (인덱스 접근으로 최적화)
    private nonisolated func convertToArray(_ fetchResult: PHFetchResult<PHAsset>) -> [PHAsset] {
        let count = fetchResult.count
        guard count > 0 else { return [] }

        var assets = [PHAsset]()
        assets.reserveCapacity(count)

        for index in 0..<count {
            assets.append(fetchResult.object(at: index))
        }

        return assets
    }

    // MARK: - Issue Detection

    /// 문제 감지 (동기 - PHAssetResource 기반으로 빠름)
    private nonisolated func detectIssues(
        for asset: PHAsset,
        types: [IssueType]? = nil
    ) -> [PhotoIssue] {
        let targetTypes = types ?? IssueType.allCases
        var issues: [PhotoIssue] = []

        for type in targetTypes {
            if let issue = detectIssue(for: asset, type: type) {
                issues.append(issue)
            }
        }

        return issues
    }

    private nonisolated func detectIssue(for asset: PHAsset, type: IssueType) -> PhotoIssue? {
        switch type {
        case .downloadFailed:
            return detectDownloadFailure(for: asset)
        case .screenshot:
            return detectScreenshot(for: asset)
        case .corrupted:
            return detectCorruption(for: asset)
        case .largeFile:
            return detectLargeFile(for: asset)
        case .duplicate:
            // TODO: Phase 2에서 구현 예정 - 해시 기반 중복 감지
            return nil
        }
    }

    // MARK: - Detection Methods

    /// iCloud 다운로드 실패 감지 (PHAssetResource 사용 - 이미지 로드 없이 빠른 확인)
    private nonisolated func detectDownloadFailure(for asset: PHAsset) -> PhotoIssue? {
        let resources = PHAssetResource.assetResources(for: asset)

        // 리소스가 없으면 검사 불가
        guard !resources.isEmpty else { return nil }

        // 로컬에 있는 리소스 확인
        // - .photo: 원본 사진
        // - .fullSizePhoto: 편집된 전체 크기 사진
        // - .alternatePhoto: 대체 사진 (HDR 등)
        // - .adjustmentBasePhoto: 편집 기준 사진
        let localResourceTypes: Set<PHAssetResourceType> = [
            .photo,
            .fullSizePhoto,
            .alternatePhoto,
            .adjustmentBasePhoto
        ]

        let hasLocalResource = resources.contains { resource in
            localResourceTypes.contains(resource.type)
        }

        // 로컬 리소스가 없으면 iCloud에만 있음
        if !hasLocalResource {
            // 사용자에게 보여줄 리소스 타입 정보
            let resourceTypeNames = resources.map { resourceTypeName($0.type) }
            let uniqueTypes = Array(Set(resourceTypeNames)).sorted()

            return PhotoIssue(
                asset: asset,
                issueType: .downloadFailed,
                severity: .warning,
                metadata: IssueMetadata(
                    errorMessage: "로컬: \(uniqueTypes.joined(separator: ", "))"
                )
            )
        }

        return nil
    }

    /// 리소스 타입을 사용자 친화적 이름으로 변환
    private nonisolated func resourceTypeName(_ type: PHAssetResourceType) -> String {
        switch type {
        case .photo: return "원본"
        case .fullSizePhoto: return "전체크기"
        case .alternatePhoto: return "대체"
        case .adjustmentBasePhoto: return "편집원본"
        case .adjustmentData: return "편집데이터"
        case .photoProxy: return "썸네일"
        case .video, .fullSizeVideo, .pairedVideo: return "비디오"
        case .adjustmentBasePairedVideo, .fullSizePairedVideo, .adjustmentBaseVideo: return "비디오편집"
        case .audio: return "오디오"
        @unknown default: return "기타"
        }
    }

    /// 스크린샷 감지
    private nonisolated func detectScreenshot(for asset: PHAsset) -> PhotoIssue? {
        guard asset.mediaSubtypes.contains(.photoScreenshot) else {
            return nil
        }

        // 파일 크기 추정 (픽셀 기반)
        let estimatedSize = estimateFileSize(for: asset)

        return PhotoIssue(
            asset: asset,
            issueType: .screenshot,
            severity: .info,
            metadata: IssueMetadata(fileSize: estimatedSize)
        )
    }

    /// 손상된 사진 감지 (기본 검사)
    private nonisolated func detectCorruption(for asset: PHAsset) -> PhotoIssue? {
        let resources = PHAssetResource.assetResources(for: asset)

        // 리소스가 없으면 손상 가능성
        if resources.isEmpty {
            return PhotoIssue(
                asset: asset,
                issueType: .corrupted,
                severity: .critical,
                metadata: IssueMetadata(
                    errorMessage: "사진 리소스를 찾을 수 없음",
                    canRecover: false
                )
            )
        }

        // 픽셀 크기가 0인 경우 손상 가능성
        if asset.pixelWidth == 0 || asset.pixelHeight == 0 {
            return PhotoIssue(
                asset: asset,
                issueType: .corrupted,
                severity: .critical,
                metadata: IssueMetadata(
                    errorMessage: "이미지 크기가 0",
                    canRecover: false
                )
            )
        }

        return nil
    }

    /// 대용량 파일 감지 (픽셀 기반 추정)
    private nonisolated func detectLargeFile(for asset: PHAsset) -> PhotoIssue? {
        let estimatedSize = estimateFileSize(for: asset)

        guard let fileSize = estimatedSize,
              fileSize >= Self.largeFileThreshold else {
            return nil
        }

        return PhotoIssue(
            asset: asset,
            issueType: .largeFile,
            severity: .info,
            metadata: IssueMetadata(fileSize: fileSize)
        )
    }

    /// 파일 크기 추정 (픽셀 기반)
    /// - Note: 실제 파일 크기는 압축 방식에 따라 다르므로 추정값임
    private nonisolated func estimateFileSize(for asset: PHAsset) -> Int64? {
        let pixelCount = Int64(asset.pixelWidth) * Int64(asset.pixelHeight)
        guard pixelCount > 0 else { return nil }

        // HEIC/JPEG 평균 압축률 고려 (약 0.3~0.5 bytes per pixel)
        // 보수적으로 0.4 사용
        return Int64(Double(pixelCount) * 0.4)
    }

    // MARK: - Helper Methods

    private nonisolated func createSummaries(from issues: [PhotoIssue]) -> [IssueSummary] {
        var summaryDict: [IssueType: IssueSummary] = [:]

        for issue in issues {
            if var summary = summaryDict[issue.issueType] {
                summary.count += 1
                summary.totalSize += issue.metadata.fileSize ?? 0
                summaryDict[issue.issueType] = summary
            } else {
                summaryDict[issue.issueType] = IssueSummary(
                    issueType: issue.issueType,
                    count: 1,
                    totalSize: issue.metadata.fileSize ?? 0
                )
            }
        }

        return Array(summaryDict.values).sorted { $0.count > $1.count }
    }
}

// MARK: - PHAsset Extension

extension PHAsset {
    /// 로컬 식별자로 PHAsset 가져오기
    static func asset(withIdentifier identifier: String) -> PHAsset? {
        let result = PHAsset.fetchAssets(
            withLocalIdentifiers: [identifier],
            options: nil
        )
        return result.firstObject
    }
}
