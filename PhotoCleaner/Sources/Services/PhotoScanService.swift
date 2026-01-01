//
//  PhotoScanService.swift
//  PhotoCleaner
//
//  사진첩 스캔 및 문제 감지 서비스
//

import Photos
import UIKit

// MARK: - Scan Configuration

/// 스캔 설정 상수
enum ScanConfig {
    /// 진행률 업데이트 간격 (항목 수)
    static let progressUpdateInterval = 100
    /// 대용량 파일 기준 (bytes) - 10MB
    static let largeFileThreshold: Int64 = 10 * 1024 * 1024
    /// 진행률 업데이트 최소 시간 간격 (초)
    static let progressDebounceInterval: TimeInterval = 0.1
}

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

    // MARK: - Properties

    private var cachedResult: ScanResult?
    private var lastProgressUpdate: Date = .distantPast

    // MARK: - Public Methods

    /// 전체 스캔 수행
    func scanAll(
        progressHandler: @escaping @Sendable (ScanProgress) -> Void
    ) async throws -> ScanResult {
        // 준비 단계
        await MainActor.run {
            progressHandler(ScanProgress(phase: .preparing, current: 0, total: 0))
        }

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
            if await shouldUpdateProgress(index: index) {
                let progress = ScanProgress(phase: .scanning, current: index + 1, total: total)
                await MainActor.run {
                    progressHandler(progress)
                }
            }

            // 문제 감지
            let detectedIssues = await detectIssues(for: asset)
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
        await MainActor.run {
            progressHandler(ScanProgress(phase: .completed, current: total, total: total))
        }

        return result
    }

    /// 특정 유형만 스캔
    func scan(
        for issueTypes: [IssueType],
        progressHandler: @escaping @Sendable (ScanProgress) -> Void
    ) async throws -> ScanResult {
        await MainActor.run {
            progressHandler(ScanProgress(phase: .preparing, current: 0, total: 0))
        }

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
            if await shouldUpdateProgress(index: index) {
                let progress = ScanProgress(phase: .scanning, current: index + 1, total: total)
                await MainActor.run {
                    progressHandler(progress)
                }
            }

            let detectedIssues = await detectIssues(for: asset, types: issueTypes)
            issues.append(contentsOf: detectedIssues)
        }

        let summaries = createSummaries(from: issues)

        let result = ScanResult(
            totalPhotos: total,
            issues: issues,
            summaries: summaries,
            scannedAt: Date()
        )

        await MainActor.run {
            progressHandler(ScanProgress(phase: .completed, current: total, total: total))
        }

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
        guard index % ScanConfig.progressUpdateInterval == 0 else { return false }

        let now = Date()
        if now.timeIntervalSince(lastProgressUpdate) >= ScanConfig.progressDebounceInterval {
            lastProgressUpdate = now
            return true
        }
        return false
    }

    /// PHFetchResult를 배열로 변환
    private nonisolated func convertToArray(_ fetchResult: PHFetchResult<PHAsset>) -> [PHAsset] {
        var assets: [PHAsset] = []
        assets.reserveCapacity(fetchResult.count)
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    // MARK: - Issue Detection

    /// 비동기 문제 감지
    private func detectIssues(
        for asset: PHAsset,
        types: [IssueType]? = nil
    ) async -> [PhotoIssue] {
        let targetTypes = types ?? IssueType.allCases
        var issues: [PhotoIssue] = []

        for type in targetTypes {
            if let issue = await detectIssue(for: asset, type: type) {
                issues.append(issue)
            }
        }

        return issues
    }

    private func detectIssue(for asset: PHAsset, type: IssueType) async -> PhotoIssue? {
        switch type {
        case .downloadFailed:
            return await detectDownloadFailure(for: asset)
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

    /// iCloud 다운로드 실패 감지 (공식 API 사용)
    private func detectDownloadFailure(for asset: PHAsset) async -> PhotoIssue? {
        // 로컬 이미지 요청 시도로 iCloud 상태 확인
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false  // 네트워크 비허용으로 로컬 확인
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast

        let isLocallyAvailable = await withCheckedContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { data, _, _, info in
                // 데이터가 있으면 로컬에 있음
                let isLocal = data != nil
                // 또는 info의 에러 확인
                let isInCloud = (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
                continuation.resume(returning: isLocal && !isInCloud)
            }
        }

        if !isLocallyAvailable {
            return PhotoIssue(
                asset: asset,
                issueType: .downloadFailed,
                severity: .warning,
                metadata: IssueMetadata(
                    errorMessage: "iCloud에서 다운로드 필요"
                )
            )
        }

        return nil
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
              fileSize >= ScanConfig.largeFileThreshold else {
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
