//
//  PhotoScanService.swift
//  PhotoCleaner
//
//  사진첩 스캔 및 문제 감지 서비스
//

import Photos
import UIKit

/// 스캔 진행 상태
struct ScanProgress {
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

enum ScanPhase {
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
        var current = 0

        // 스캔 시작
        allAssets.enumerateObjects { [self] asset, index, _ in
            current = index + 1

            // 진행률 업데이트 (100개마다)
            if index % 100 == 0 {
                let progress = ScanProgress(phase: .scanning, current: current, total: total)
                Task { @MainActor in
                    progressHandler(progress)
                }
            }

            // 문제 감지
            let detectedIssues = self.detectIssuesSync(for: asset)
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

        allAssets.enumerateObjects { asset, index, _ in
            if index % 100 == 0 {
                let progress = ScanProgress(phase: .scanning, current: index + 1, total: total)
                Task { @MainActor in
                    progressHandler(progress)
                }
            }

            let detectedIssues = self.detectIssuesSync(for: asset, types: issueTypes)
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

    // MARK: - Issue Detection (Sync for enumeration)

    private nonisolated func detectIssuesSync(
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
            return nil  // 별도 처리 필요
        }
    }

    // MARK: - Detection Methods

    /// iCloud 다운로드 실패 감지
    private nonisolated func detectDownloadFailure(for asset: PHAsset) -> PhotoIssue? {
        let resources = PHAssetResource.assetResources(for: asset)

        // 원본 사진 리소스 찾기
        guard let photoResource = resources.first(where: { $0.type == .photo || $0.type == .fullSizePhoto }) else {
            return nil
        }

        // 로컬에 있는지 확인
        let isLocal = photoResource.value(forKey: "locallyAvailable") as? Bool ?? true

        // 로컬에 없으면 iCloud에서 다운로드 필요
        if !isLocal {
            // 다운로드 시도해서 실패하는지 확인하는 것은 비용이 크므로
            // 우선 로컬에 없는 것만 표시
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

        // 파일 크기 가져오기
        let resources = PHAssetResource.assetResources(for: asset)
        let fileSize = resources.first?.value(forKey: "fileSize") as? Int64

        return PhotoIssue(
            asset: asset,
            issueType: .screenshot,
            severity: .info,
            metadata: IssueMetadata(fileSize: fileSize)
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

        // 파일 크기가 0이면 손상
        if let photoResource = resources.first(where: { $0.type == .photo || $0.type == .fullSizePhoto }),
           let fileSize = photoResource.value(forKey: "fileSize") as? Int64,
           fileSize == 0 {
            return PhotoIssue(
                asset: asset,
                issueType: .corrupted,
                severity: .critical,
                metadata: IssueMetadata(
                    fileSize: 0,
                    errorMessage: "파일 크기가 0",
                    canRecover: false
                )
            )
        }

        return nil
    }

    /// 대용량 파일 감지
    private nonisolated func detectLargeFile(
        for asset: PHAsset,
        threshold: Int64 = 10 * 1024 * 1024  // 10MB
    ) -> PhotoIssue? {
        let resources = PHAssetResource.assetResources(for: asset)

        guard let photoResource = resources.first(where: { $0.type == .photo || $0.type == .fullSizePhoto }),
              let fileSize = photoResource.value(forKey: "fileSize") as? Int64,
              fileSize >= threshold else {
            return nil
        }

        return PhotoIssue(
            asset: asset,
            issueType: .largeFile,
            severity: .info,
            metadata: IssueMetadata(fileSize: fileSize)
        )
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
