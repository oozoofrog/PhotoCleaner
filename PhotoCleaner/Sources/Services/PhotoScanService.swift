//
//  PhotoScanService.swift
//  PhotoCleaner
//
//  사진첩 스캔 및 문제 감지 서비스
//

import Photos
import CryptoKit
@preconcurrency import Vision
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

/// 스캔 업데이트 이벤트 (스트리밍용)
enum ScanUpdate: Sendable {
    case progress(ScanProgress)
    case issueFound(PhotoIssue)
    case duplicateGroupFound(DuplicateGroup)
    case summaryUpdated(IssueType, count: Int)
    case completed(ScanResult)
    case cancelled(partialResult: ScanResult?)
    case failed(Error)
}

/// 스캔 결과
struct ScanResult: Sendable {
    let totalPhotos: Int
    let issues: [PhotoIssue]
    let summaries: [IssueSummary]
    let duplicateGroups: [DuplicateGroup]
    let scannedAt: Date

    nonisolated init(
        totalPhotos: Int,
        issues: [PhotoIssue],
        summaries: [IssueSummary],
        duplicateGroups: [DuplicateGroup] = [],
        scannedAt: Date
    ) {
        self.totalPhotos = totalPhotos
        self.issues = issues
        self.summaries = summaries
        self.duplicateGroups = duplicateGroups
        self.scannedAt = scannedAt
    }

    var totalIssueCount: Int {
        issues.count
    }

    var duplicateSummary: (groupCount: Int, duplicateCount: Int, potentialSavings: Int64) {
        let groupCount = duplicateGroups.count
        let duplicateCount = duplicateGroups.reduce(0) { $0 + $1.count - 1 }  // 원본 제외
        let potentialSavings = duplicateGroups.reduce(Int64(0)) { $0 + $1.potentialSavings }
        return (groupCount, duplicateCount, potentialSavings)
    }

    func issues(for type: IssueType) -> [PhotoIssue] {
        issues.filter { $0.issueType == type }
    }

    func summary(for type: IssueType) -> IssueSummary? {
        summaries.first { $0.issueType == type }
    }
}

actor PhotoScanService {

    // MARK: - Constants

    private nonisolated static let progressUpdateInterval: Int = 100
    private nonisolated static let progressDebounceInterval: TimeInterval = 0.1

    // MARK: - Dependencies

    private let photoAssetService: any PhotoAssetService

    // MARK: - Properties

    private var cachedResult: ScanResult?
    private var lastProgressUpdate: Date = .distantPast
    private(set) var largeFileThreshold: Int64 = 10 * 1024 * 1024

    /// 현재 스캔 취소 플래그
    private var isCancelled: Bool = false

    init(photoAssetService: some PhotoAssetService) {
        self.photoAssetService = photoAssetService
    }

    func setLargeFileThreshold(_ threshold: LargeFileSizeOption) {
        largeFileThreshold = threshold.rawValue
        cachedResult = nil
    }

    /// 스캔 취소
    func cancelScan() {
        isCancelled = true
    }

    /// 취소 상태 초기화
    private func resetCancellation() {
        isCancelled = false
    }

    // MARK: - Public Methods

    /// 스트리밍 스캔 API - 실시간으로 발견된 이슈를 yield
    func scanAllStreaming(
        duplicateDetectionMode: DuplicateDetectionMode = .includeSimilar,
        similarityThreshold: SimilarityThreshold = .percent95
    ) -> AsyncStream<ScanUpdate> {
        AsyncStream { continuation in
            let task = Task { [weak self] in
                guard let self = self else {
                    continuation.finish()
                    return
                }

                await self.resetCancellation()

                // 준비 단계
                continuation.yield(.progress(ScanProgress(phase: .preparing, current: 0, total: 0)))

                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                let allAssets = PHAsset.fetchAssets(with: .image, options: fetchOptions)

                let total = allAssets.count
                var issues: [PhotoIssue] = []
                var summaryDict: [IssueType: Int] = [:]

                let assets = await self.convertToArray(allAssets)
                let threshold = await self.largeFileThreshold

                // 메타데이터 스캔 (이슈 감지)
                for (index, asset) in assets.enumerated() {
                    // 취소 확인
                    if await self.isCancelled || Task.isCancelled {
                        let partialResult = await self.createPartialResult(
                            totalPhotos: total,
                            issues: issues,
                            duplicateGroups: []
                        )
                        continuation.yield(.cancelled(partialResult: partialResult))
                        continuation.finish()
                        return
                    }

                    // 진행률 업데이트
                    if await self.shouldUpdateProgress(index: index) {
                        let progress = ScanProgress(phase: .scanning, current: index + 1, total: total)
                        continuation.yield(.progress(progress))
                    }

                    // 이슈 감지
                    let detectedIssues = self.detectIssues(for: asset, largeFileThreshold: threshold)
                    for issue in detectedIssues {
                        issues.append(issue)
                        summaryDict[issue.issueType, default: 0] += 1

                        // 실시간으로 이슈 yield
                        continuation.yield(.issueFound(issue))
                        continuation.yield(.summaryUpdated(issue.issueType, count: summaryDict[issue.issueType]!))
                    }
                }

                // 중복 스캔 (정확히 일치)
                let duplicateResult = await self.scanExactDuplicatesStreaming(
                    assets: assets,
                    continuation: continuation
                )

                // 취소 확인
                if await self.isCancelled || Task.isCancelled {
                    let partialResult = await self.createPartialResult(
                        totalPhotos: total,
                        issues: issues + duplicateResult.issues,
                        duplicateGroups: duplicateResult.groups
                    )
                    continuation.yield(.cancelled(partialResult: partialResult))
                    continuation.finish()
                    return
                }

                issues.append(contentsOf: duplicateResult.issues)
                var allDuplicateGroups = duplicateResult.groups

                // 유사 이미지 스캔
                if duplicateDetectionMode == .includeSimilar {
                    let exactDuplicateAssetIds = Set(duplicateResult.groups.flatMap { $0.assetIdentifiers })
                    let remainingAssets = assets.filter { !exactDuplicateAssetIds.contains($0.localIdentifier) }

                    let similarResult = await self.scanSimilarPhotosStreaming(
                        assets: remainingAssets,
                        similarityThreshold: similarityThreshold.floatValue,
                        continuation: continuation
                    )

                    // 취소 확인
                    if await self.isCancelled || Task.isCancelled {
                        let partialResult = await self.createPartialResult(
                            totalPhotos: total,
                            issues: issues + similarResult.issues,
                            duplicateGroups: allDuplicateGroups + similarResult.groups
                        )
                        continuation.yield(.cancelled(partialResult: partialResult))
                        continuation.finish()
                        return
                    }

                    issues.append(contentsOf: similarResult.issues)
                    allDuplicateGroups.append(contentsOf: similarResult.groups)
                }

                // 최종 결과 생성
                let summaries = self.createSummaries(from: issues)
                let result = ScanResult(
                    totalPhotos: total,
                    issues: issues,
                    summaries: summaries,
                    duplicateGroups: allDuplicateGroups,
                    scannedAt: Date()
                )

                await self.setCachedResult(result)

                continuation.yield(.progress(ScanProgress(phase: .completed, current: total, total: total)))
                continuation.yield(.completed(result))
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// 부분 결과 생성 (취소 시 사용)
    private nonisolated func createPartialResult(
        totalPhotos: Int,
        issues: [PhotoIssue],
        duplicateGroups: [DuplicateGroup]
    ) -> ScanResult {
        let summaries = createSummaries(from: issues)
        return ScanResult(
            totalPhotos: totalPhotos,
            issues: issues,
            summaries: summaries,
            duplicateGroups: duplicateGroups,
            scannedAt: Date()
        )
    }

    /// 캐시 설정 (actor 격리)
    private func setCachedResult(_ result: ScanResult) {
        cachedResult = result
    }

    // MARK: - Streaming Duplicate Detection

    /// 정확히 일치하는 중복 스캔 (스트리밍)
    private func scanExactDuplicatesStreaming(
        assets: [PHAsset],
        continuation: AsyncStream<ScanUpdate>.Continuation
    ) async -> (issues: [PhotoIssue], groups: [DuplicateGroup]) {
        let total = assets.count

        // Metadata Pre-filtering: Group by dimensions
        var potentialGroups: [String: [PHAsset]] = [:]
        for asset in assets {
            let key = "\(asset.pixelWidth)x\(asset.pixelHeight)"
            potentialGroups[key, default: []].append(asset)
        }

        let candidates = potentialGroups.values.filter { $0.count > 1 }.flatMap { $0 }

        if candidates.isEmpty {
            continuation.yield(.progress(ScanProgress(phase: .scanning, current: total, total: total, currentIssueType: .duplicate)))
            return ([], [])
        }

        // Parallel Hashing for candidates
        let hashToAssets = await withTaskGroup(of: (String, DuplicateCandidate)?.self, returning: [String: [DuplicateCandidate]].self) { group in
            let maxConcurrent = 4
            var iterator = candidates.makeIterator()
            var results: [String: [DuplicateCandidate]] = [:]
            var processedCount = 0

            func addNext() {
                if let asset = iterator.next() {
                    group.addTask(priority: .userInitiated) {
                        guard let result = await self.computeAssetHash(asset) else { return nil }
                        return (result.hashHex, DuplicateCandidate(
                            assetId: asset.localIdentifier,
                            hashHex: result.hashHex,
                            pixelWidth: asset.pixelWidth,
                            pixelHeight: asset.pixelHeight,
                            creationDate: asset.creationDate,
                            byteCount: result.byteCount
                        ))
                    }
                }
            }

            for _ in 0..<maxConcurrent {
                addNext()
            }

            for await result in group {
                processedCount += 1
                if self.shouldUpdateProgress(index: processedCount) {
                    continuation.yield(.progress(ScanProgress(
                        phase: .scanning,
                        current: processedCount,
                        total: candidates.count,
                        currentIssueType: .duplicate
                    )))
                }

                if let (hash, candidate) = result {
                    results[hash, default: []].append(candidate)
                }

                addNext()
            }

            return results
        }

        continuation.yield(.progress(ScanProgress(phase: .scanning, current: total, total: total, currentIssueType: .duplicate)))

        // 결과 생성 및 실시간 yield
        let result = createDuplicateResultsStreaming(from: hashToAssets, assets: assets, continuation: continuation)
        return result
    }

    /// 중복 결과 생성 및 실시간 yield
    private nonisolated func createDuplicateResultsStreaming(
        from hashToAssets: [String: [DuplicateCandidate]],
        assets: [PHAsset],
        continuation: AsyncStream<ScanUpdate>.Continuation
    ) -> (issues: [PhotoIssue], groups: [DuplicateGroup]) {
        var groups: [DuplicateGroup] = []
        var issues: [PhotoIssue] = []

        let assetMap = Dictionary(uniqueKeysWithValues: assets.map { ($0.localIdentifier, $0) })

        for (hash, candidates) in hashToAssets where candidates.count >= 2 {
            let sortedCandidates = selectOriginalFirst(candidates: candidates)
            let originalId = sortedCandidates[0].assetId
            let potentialSavings = sortedCandidates.dropFirst().reduce(Int64(0)) { $0 + $1.byteCount }

            let group = DuplicateGroup(
                id: "sha256:\(hash.prefix(16))",
                assetIdentifiers: sortedCandidates.map { $0.assetId },
                suggestedOriginalId: originalId,
                similarity: 1.0,
                potentialSavings: potentialSavings
            )
            groups.append(group)

            // 실시간으로 그룹 yield
            continuation.yield(.duplicateGroupFound(group))

            for candidate in sortedCandidates.dropFirst() {
                guard let asset = assetMap[candidate.assetId] else { continue }
                let issue = PhotoIssue(
                    asset: asset,
                    issueType: .duplicate,
                    severity: .info,
                    metadata: IssueMetadata(
                        fileSize: candidate.byteCount,
                        duplicateGroupId: group.id
                    )
                )
                issues.append(issue)
                continuation.yield(.issueFound(issue))
            }
        }

        return (issues, groups)
    }

    /// 유사 이미지 스캔 (스트리밍)
    private func scanSimilarPhotosStreaming(
        assets: [PHAsset],
        similarityThreshold: Float,
        continuation: AsyncStream<ScanUpdate>.Continuation
    ) async -> (issues: [PhotoIssue], groups: [DuplicateGroup]) {
        let buckets = bucketAssetsByMetadata(assets)
        let assetMap = Dictionary(uniqueKeysWithValues: assets.map { ($0.localIdentifier, $0) })

        var allIssues: [PhotoIssue] = []
        var allGroups: [DuplicateGroup] = []
        var processedCount = 0
        let total = assets.count

        for (_, bucketAssets) in buckets {
            // 취소 확인
            if isCancelled || Task.isCancelled {
                return (allIssues, allGroups)
            }

            let candidates = await withTaskGroup(of: FeaturePrintCandidate?.self, returning: [FeaturePrintCandidate].self) { group in
                var iterator = bucketAssets.makeIterator()
                var bucketCandidates: [FeaturePrintCandidate] = []

                for _ in 0..<Self.maxConcurrentFeaturePrints {
                    guard let asset = iterator.next() else { break }
                    group.addTask(priority: .userInitiated) {
                        guard let result = await self.computeFeaturePrint(for: asset) else { return nil }
                        let bucketKey = self.computeBucketKey(for: asset)
                        return FeaturePrintCandidate(
                            assetId: asset.localIdentifier,
                            featurePrint: result.featurePrint,
                            pixelWidth: asset.pixelWidth,
                            pixelHeight: asset.pixelHeight,
                            creationDate: asset.creationDate,
                            byteCount: result.byteCount,
                            bucketKey: bucketKey
                        )
                    }
                }

                for await result in group {
                    processedCount += 1
                    if self.shouldUpdateProgress(index: processedCount) {
                        continuation.yield(.progress(ScanProgress(
                            phase: .scanning,
                            current: processedCount,
                            total: total,
                            currentIssueType: .duplicate
                        )))
                    }

                    if let candidate = result {
                        bucketCandidates.append(candidate)
                    }

                    if let nextAsset = iterator.next() {
                        group.addTask(priority: .userInitiated) {
                            guard let result = await self.computeFeaturePrint(for: nextAsset) else { return nil }
                            let bucketKey = self.computeBucketKey(for: nextAsset)
                            return FeaturePrintCandidate(
                                assetId: nextAsset.localIdentifier,
                                featurePrint: result.featurePrint,
                                pixelWidth: nextAsset.pixelWidth,
                                pixelHeight: nextAsset.pixelHeight,
                                creationDate: nextAsset.creationDate,
                                byteCount: result.byteCount,
                                bucketKey: bucketKey
                            )
                        }
                    }
                }
                return bucketCandidates
            }

            let bucketResult = groupSimilarCandidatesStreaming(candidates, threshold: similarityThreshold, assetMap: assetMap, continuation: continuation)
            allIssues.append(contentsOf: bucketResult.issues)
            allGroups.append(contentsOf: bucketResult.groups)
        }

        return (allIssues, allGroups)
    }

    /// 유사 이미지 그룹화 및 실시간 yield
    private nonisolated func groupSimilarCandidatesStreaming(
        _ candidates: [FeaturePrintCandidate],
        threshold: Float,
        assetMap: [String: PHAsset],
        continuation: AsyncStream<ScanUpdate>.Continuation
    ) -> (issues: [PhotoIssue], groups: [DuplicateGroup]) {
        guard candidates.count >= 2 else { return ([], []) }

        var parent = Array(0..<candidates.count)
        var rank = Array(repeating: 0, count: candidates.count)

        func find(_ x: Int) -> Int {
            if parent[x] != x {
                parent[x] = find(parent[x])
            }
            return parent[x]
        }

        func union(_ x: Int, _ y: Int) {
            let px = find(x)
            let py = find(y)
            guard px != py else { return }

            if rank[px] < rank[py] {
                parent[px] = py
            } else if rank[px] > rank[py] {
                parent[py] = px
            } else {
                parent[py] = px
                rank[px] += 1
            }
        }

        let distanceThreshold = 1.0 - threshold

        for i in 0..<candidates.count {
            for j in (i + 1)..<candidates.count {
                var distance: Float = 0
                do {
                    try candidates[i].featurePrint.computeDistance(&distance, to: candidates[j].featurePrint)
                    if distance <= distanceThreshold {
                        union(i, j)
                    }
                } catch {
                    continue
                }
            }
        }

        var groupMap: [Int: [Int]] = [:]
        for i in 0..<candidates.count {
            let root = find(i)
            groupMap[root, default: []].append(i)
        }

        var groups: [DuplicateGroup] = []
        var issues: [PhotoIssue] = []

        for (_, memberIndices) in groupMap where memberIndices.count >= 2 {
            let members = memberIndices.map { candidates[$0] }
            let sortedMembers = sortByOriginalPriority(members)
            let originalId = sortedMembers[0].assetId
            let potentialSavings = sortedMembers.dropFirst().reduce(Int64(0)) { $0 + $1.byteCount }

            let groupId = "similar:\(UUID().uuidString.prefix(8))"
            let group = DuplicateGroup(
                id: groupId,
                assetIdentifiers: sortedMembers.map { $0.assetId },
                suggestedOriginalId: originalId,
                similarity: Double(threshold),
                potentialSavings: potentialSavings
            )
            groups.append(group)

            // 실시간으로 그룹 yield
            continuation.yield(.duplicateGroupFound(group))

            for member in sortedMembers.dropFirst() {
                guard let asset = assetMap[member.assetId] else { continue }
                let issue = PhotoIssue(
                    asset: asset,
                    issueType: .duplicate,
                    severity: .info,
                    metadata: IssueMetadata(
                        fileSize: member.byteCount,
                        duplicateGroupId: groupId
                    )
                )
                issues.append(issue)
                continuation.yield(.issueFound(issue))
            }
        }

        return (issues, groups)
    }

    func scanAll(
        duplicateDetectionMode: DuplicateDetectionMode = .includeSimilar,
        similarityThreshold: SimilarityThreshold = .percent95,
        progressHandler: @escaping @MainActor @Sendable (ScanProgress) -> Void
    ) async throws -> ScanResult {
        await progressHandler(ScanProgress(phase: .preparing, current: 0, total: 0))

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let allAssets = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        let total = allAssets.count
        var issues: [PhotoIssue] = []

        let assets = convertToArray(allAssets)
        let threshold = largeFileThreshold

        for (index, asset) in assets.enumerated() {
            if shouldUpdateProgress(index: index) {
                let progress = ScanProgress(phase: .scanning, current: index + 1, total: total)
                await progressHandler(progress)
            }

            let detectedIssues = detectIssues(for: asset, largeFileThreshold: threshold)
            issues.append(contentsOf: detectedIssues)
        }

        let duplicateResult = await scanExactDuplicates(assets: assets, progressHandler: progressHandler)
        issues.append(contentsOf: duplicateResult.issues)

        var allDuplicateGroups = duplicateResult.groups

        if duplicateDetectionMode == .includeSimilar {
            let exactDuplicateAssetIds = Set(duplicateResult.groups.flatMap { $0.assetIdentifiers })
            let remainingAssets = assets.filter { !exactDuplicateAssetIds.contains($0.localIdentifier) }
            
            let similarResult = await scanSimilarPhotos(
                assets: remainingAssets,
                similarityThreshold: duplicateDetectionMode == .includeSimilar ? similarityThreshold.floatValue : 1.0,
                progressHandler: progressHandler
            )
            issues.append(contentsOf: similarResult.issues)
            allDuplicateGroups.append(contentsOf: similarResult.groups)
        }

        let summaries = createSummaries(from: issues)

        let result = ScanResult(
            totalPhotos: total,
            issues: issues,
            summaries: summaries,
            duplicateGroups: allDuplicateGroups,
            scannedAt: Date()
        )

        cachedResult = result

        await progressHandler(ScanProgress(phase: .completed, current: total, total: total))

        return result
    }

    func scan(
        for issueTypes: [IssueType],
        duplicateDetectionMode: DuplicateDetectionMode = .includeSimilar,
        similarityThreshold: SimilarityThreshold = .percent95,
        progressHandler: @escaping @MainActor @Sendable (ScanProgress) -> Void
    ) async throws -> ScanResult {
        await progressHandler(ScanProgress(phase: .preparing, current: 0, total: 0))

        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        if issueTypes == [.screenshot] {
            fetchOptions.predicate = NSPredicate(
                format: "(mediaSubtypes & %d) != 0",
                PHAssetMediaSubtype.photoScreenshot.rawValue
            )
        }

        let allAssets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        let total = allAssets.count
        var issues: [PhotoIssue] = []
        var duplicateGroups: [DuplicateGroup] = []

        let assets = convertToArray(allAssets)
        let metadataTypes = issueTypes.filter { $0 != .duplicate }
        let threshold = largeFileThreshold

        for (index, asset) in assets.enumerated() {
            if shouldUpdateProgress(index: index) {
                let progress = ScanProgress(phase: .scanning, current: index + 1, total: total)
                await progressHandler(progress)
            }

            let detectedIssues = detectIssues(for: asset, types: metadataTypes, largeFileThreshold: threshold)
            issues.append(contentsOf: detectedIssues)
        }

        if issueTypes.contains(.duplicate) {
            let duplicateResult = await scanExactDuplicates(assets: assets, progressHandler: progressHandler)
            issues.append(contentsOf: duplicateResult.issues)
            duplicateGroups = duplicateResult.groups

            if duplicateDetectionMode == .includeSimilar {
                let exactDuplicateAssetIds = Set(duplicateResult.groups.flatMap { $0.assetIdentifiers })
                let remainingAssets = assets.filter { !exactDuplicateAssetIds.contains($0.localIdentifier) }
                
                let similarResult = await scanSimilarPhotos(
                    assets: remainingAssets,
                    similarityThreshold: similarityThreshold.floatValue,
                    progressHandler: progressHandler
                )
                issues.append(contentsOf: similarResult.issues)
                duplicateGroups.append(contentsOf: similarResult.groups)
            }
        }

        let summaries = createSummaries(from: issues)

        let result = ScanResult(
            totalPhotos: total,
            issues: issues,
            summaries: summaries,
            duplicateGroups: duplicateGroups,
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

    private nonisolated func detectIssues(
        for asset: PHAsset,
        types: [IssueType]? = nil,
        largeFileThreshold: Int64 = 10 * 1024 * 1024
    ) -> [PhotoIssue] {
        let targetTypes = types ?? IssueType.allCases
        var issues: [PhotoIssue] = []

        for type in targetTypes {
            if let issue = detectIssue(for: asset, type: type, largeFileThreshold: largeFileThreshold) {
                issues.append(issue)
            }
        }

        return issues
    }

    private nonisolated func detectIssue(
        for asset: PHAsset,
        type: IssueType,
        largeFileThreshold: Int64 = 10 * 1024 * 1024
    ) -> PhotoIssue? {
        switch type {
        case .downloadFailed:
            return detectDownloadFailure(for: asset)
        case .screenshot:
            return detectScreenshot(for: asset)
        case .corrupted:
            return detectCorruption(for: asset)
        case .largeFile:
            return detectLargeFile(for: asset, threshold: largeFileThreshold)
        case .duplicate:
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

    private nonisolated func detectLargeFile(for asset: PHAsset, threshold: Int64) -> PhotoIssue? {
        let estimatedSize = estimateFileSize(for: asset)

        guard let fileSize = estimatedSize,
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

    // MARK: - Duplicate Detection

    private struct DuplicateCandidate: Sendable {
        let assetId: String
        let hashHex: String
        let pixelWidth: Int
        let pixelHeight: Int
        let creationDate: Date?
        let byteCount: Int64

        var resolution: Int { pixelWidth * pixelHeight }
    }

    func scanExactDuplicates(
        assets: [PHAsset],
        progressHandler: @escaping @MainActor @Sendable (ScanProgress) -> Void
    ) async -> (issues: [PhotoIssue], groups: [DuplicateGroup]) {
        let total = assets.count
        
        // 1. Metadata Pre-filtering: Group by dimensions
        // Exact duplicates MUST have same dimensions. This filters out 90%+ of unique photos.
        var potentialGroups: [String: [PHAsset]] = [:]
        for asset in assets {
            let key = "\(asset.pixelWidth)x\(asset.pixelHeight)"
            potentialGroups[key, default: []].append(asset)
        }
        
        let candidates = potentialGroups.values.filter { $0.count > 1 }.flatMap { $0 }
        
        // If no potential duplicates found by metadata, return early
        if candidates.isEmpty { 
            await progressHandler(ScanProgress(phase: .scanning, current: total, total: total, currentIssueType: .duplicate))
            return ([], []) 
        }
        
        // 2. Parallel Hashing for candidates
        let hashToAssets = await withTaskGroup(of: (String, DuplicateCandidate)?.self, returning: [String: [DuplicateCandidate]].self) { group in
            
            // Limit concurrency (e.g. 4)
            let maxConcurrent = 4
            var activeAssets = 0
            var iterator = candidates.makeIterator()
            var results: [String: [DuplicateCandidate]] = [:]
            var processedCount = 0
            
            // Function to add work
            func addNext() {
                if let asset = iterator.next() {
                    group.addTask(priority: .userInitiated) {
                        guard let result = await self.computeAssetHash(asset) else { return nil }
                        
                        return (result.hashHex, DuplicateCandidate(
                            assetId: asset.localIdentifier,
                            hashHex: result.hashHex,
                            pixelWidth: asset.pixelWidth,
                            pixelHeight: asset.pixelHeight,
                            creationDate: asset.creationDate,
                            byteCount: result.byteCount
                        ))
                    }
                    activeAssets += 1
                }
            }
            
            // Initial fill
            for _ in 0..<maxConcurrent {
                addNext()
            }
            
            // Process results
            for await result in group {
                processedCount += 1
                
                // Update progress occasionally
                if self.shouldUpdateProgress(index: processedCount) {
                    await progressHandler(ScanProgress(
                        phase: .scanning,
                        current: processedCount, // Note: This progress display logic might be jumpy relative to 'total' which is all assets.
                        total: candidates.count, // Show progress relative to candidates? Or stick to main flow.
                        currentIssueType: .duplicate
                    ))
                }
                
                if let (hash, candidate) = result {
                    results[hash, default: []].append(candidate)
                }
                
                activeAssets -= 1
                addNext()
            }
            
            return results
        }
        
        // Final progress update
        await progressHandler(ScanProgress(phase: .scanning, current: total, total: total, currentIssueType: .duplicate))

        return createDuplicateResults(from: hashToAssets, assets: assets)
    }

    private func computeAssetHash(_ asset: PHAsset) async -> (hashHex: String, byteCount: Int64)? {
        let resources = PHAssetResource.assetResources(for: asset)

        let targetTypes: [PHAssetResourceType] = [.fullSizePhoto, .photo]
        guard let resource = resources.first(where: { targetTypes.contains($0.type) }) else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            var hasher = SHA256()
            var byteCount: Int64 = 0
            var hasResumed = false

            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = false

            PHAssetResourceManager.default().requestData(
                for: resource,
                options: options,
                dataReceivedHandler: { data in
                    hasher.update(data: data)
                    byteCount += Int64(data.count)
                },
                completionHandler: { error in
                    guard !hasResumed else { return }
                    hasResumed = true

                    if error != nil {
                        continuation.resume(returning: nil)
                        return
                    }

                    let digest = hasher.finalize()
                    let hashHex = digest.map { String(format: "%02x", $0) }.joined()
                    continuation.resume(returning: (hashHex, byteCount))
                }
            )
        }
    }

    private nonisolated func createDuplicateResults(
        from hashToAssets: [String: [DuplicateCandidate]],
        assets: [PHAsset]
    ) -> (issues: [PhotoIssue], groups: [DuplicateGroup]) {
        var groups: [DuplicateGroup] = []
        var issues: [PhotoIssue] = []

        let assetMap = Dictionary(uniqueKeysWithValues: assets.map { ($0.localIdentifier, $0) })

        for (hash, candidates) in hashToAssets where candidates.count >= 2 {
            let sortedCandidates = selectOriginalFirst(candidates: candidates)
            let originalId = sortedCandidates[0].assetId
            let potentialSavings = sortedCandidates.dropFirst().reduce(Int64(0)) { $0 + $1.byteCount }

            let group = DuplicateGroup(
                id: "sha256:\(hash.prefix(16))",
                assetIdentifiers: sortedCandidates.map { $0.assetId },
                suggestedOriginalId: originalId,
                similarity: 1.0,
                potentialSavings: potentialSavings
            )
            groups.append(group)

            for candidate in sortedCandidates.dropFirst() {
                guard let asset = assetMap[candidate.assetId] else { continue }
                let issue = PhotoIssue(
                    asset: asset,
                    issueType: .duplicate,
                    severity: .info,
                    metadata: IssueMetadata(
                        fileSize: candidate.byteCount,
                        duplicateGroupId: group.id
                    )
                )
                issues.append(issue)
            }
        }

        return (issues, groups)
    }

    private nonisolated func selectOriginalFirst(candidates: [DuplicateCandidate]) -> [DuplicateCandidate] {
        candidates.sorted { lhs, rhs in
            if lhs.resolution != rhs.resolution {
                return lhs.resolution > rhs.resolution
            }
            if lhs.byteCount != rhs.byteCount {
                return lhs.byteCount > rhs.byteCount
            }
            let lhsDate = lhs.creationDate ?? .distantFuture
            let rhsDate = rhs.creationDate ?? .distantFuture
            if lhsDate != rhsDate {
                return lhsDate < rhsDate
            }
            return lhs.assetId < rhs.assetId
        }
    }

    // MARK: - Similar Photo Detection (Vision pHash)

    private struct FeaturePrintCandidate: @unchecked Sendable {
        let assetId: String
        let featurePrint: VNFeaturePrintObservation
        let pixelWidth: Int
        let pixelHeight: Int
        let creationDate: Date?
        let byteCount: Int64
        let bucketKey: String

        var resolution: Int { pixelWidth * pixelHeight }
    }

    private struct VisionResult: @unchecked Sendable {
        let featurePrint: VNFeaturePrintObservation
        let byteCount: Int64
    }

    private nonisolated static let maxBucketSize = 100
    private nonisolated static let maxConcurrentFeaturePrints = 4

    func scanSimilarPhotos(
        assets: [PHAsset],
        similarityThreshold: Float = 0.95,
        progressHandler: @escaping @MainActor @Sendable (ScanProgress) -> Void
    ) async -> (issues: [PhotoIssue], groups: [DuplicateGroup]) {
        let buckets = bucketAssetsByMetadata(assets)
        let assetMap = Dictionary(uniqueKeysWithValues: assets.map { ($0.localIdentifier, $0) })

        var allIssues: [PhotoIssue] = []
        var allGroups: [DuplicateGroup] = []
        var processedCount = 0
        let total = assets.count

        for (_, bucketAssets) in buckets {
            // Parallelize Vision Processing within Bucket (with throttling)
            let candidates = await withTaskGroup(of: FeaturePrintCandidate?.self, returning: [FeaturePrintCandidate].self) { group in
                var iterator = bucketAssets.makeIterator()
                var bucketCandidates: [FeaturePrintCandidate] = []

                // Start initial batch of concurrent tasks (limited to maxConcurrentFeaturePrints)
                for _ in 0..<Self.maxConcurrentFeaturePrints {
                    guard let asset = iterator.next() else { break }
                    group.addTask(priority: .userInitiated) {
                        guard let result = await self.computeFeaturePrint(for: asset) else { return nil }
                        let bucketKey = self.computeBucketKey(for: asset)
                        return FeaturePrintCandidate(
                            assetId: asset.localIdentifier,
                            featurePrint: result.featurePrint,
                            pixelWidth: asset.pixelWidth,
                            pixelHeight: asset.pixelHeight,
                            creationDate: asset.creationDate,
                            byteCount: result.byteCount,
                            bucketKey: bucketKey
                        )
                    }
                }

                // As tasks complete, add new ones to maintain concurrency limit
                for await result in group {
                    processedCount += 1
                    if self.shouldUpdateProgress(index: processedCount) {
                        await progressHandler(ScanProgress(
                            phase: .scanning,
                            current: processedCount,
                            total: total,
                            currentIssueType: .duplicate
                        ))
                    }

                    if let candidate = result {
                        bucketCandidates.append(candidate)
                    }

                    // Add next task if there are more assets
                    if let nextAsset = iterator.next() {
                        group.addTask(priority: .userInitiated) {
                            guard let result = await self.computeFeaturePrint(for: nextAsset) else { return nil }
                            let bucketKey = self.computeBucketKey(for: nextAsset)
                            return FeaturePrintCandidate(
                                assetId: nextAsset.localIdentifier,
                                featurePrint: result.featurePrint,
                                pixelWidth: nextAsset.pixelWidth,
                                pixelHeight: nextAsset.pixelHeight,
                                creationDate: nextAsset.creationDate,
                                byteCount: result.byteCount,
                                bucketKey: bucketKey
                            )
                        }
                    }
                }
                return bucketCandidates
            }

            let bucketResult = groupSimilarCandidates(candidates, threshold: similarityThreshold, assetMap: assetMap)
            allIssues.append(contentsOf: bucketResult.issues)
            allGroups.append(contentsOf: bucketResult.groups)
        }

        return (allIssues, allGroups)
    }

    private nonisolated func bucketAssetsByMetadata(_ assets: [PHAsset]) -> [String: [PHAsset]] {
        var buckets: [String: [PHAsset]] = [:]

        for asset in assets {
            let key = computeBucketKey(for: asset)
            buckets[key, default: []].append(asset)
        }

        var result: [String: [PHAsset]] = [:]
        for (key, bucketAssets) in buckets {
            if bucketAssets.count <= Self.maxBucketSize {
                result[key] = bucketAssets
            } else {
                for (index, chunk) in bucketAssets.chunked(into: Self.maxBucketSize).enumerated() {
                    result["\(key)-\(index)"] = chunk
                }
            }
        }

        return result
    }

    private nonisolated func computeBucketKey(for asset: PHAsset) -> String {
        let calendar = Calendar.current
        let dateKey: String
        if let date = asset.creationDate {
            let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 0
            let year = calendar.component(.year, from: date)
            let weekBucket = dayOfYear / 7
            dateKey = "\(year)-w\(weekBucket)"
        } else {
            dateKey = "unknown"
        }

        let aspectRatio = asset.pixelHeight > 0 ? Double(asset.pixelWidth) / Double(asset.pixelHeight) : 1.0
        let aspectBucket = Int(aspectRatio * 5) / 5

        let resolutionBucket: String
        let megapixels = (asset.pixelWidth * asset.pixelHeight) / 1_000_000
        if megapixels < 4 {
            resolutionBucket = "low"
        } else if megapixels < 12 {
            resolutionBucket = "medium"
        } else {
            resolutionBucket = "high"
        }

        return "\(dateKey)_\(aspectBucket)_\(resolutionBucket)"
    }

    private func computeFeaturePrint(for asset: PHAsset) async -> VisionResult? {
        let scale = await MainActor.run { UITraitCollection.current.displayScale }
        let targetSize = CGSize(width: 300, height: 300)
        
        do {
            let (cgImage, byteCount) = try await photoAssetService.requestThumbnailCGImageForVision(
                for: asset,
                pointSize: targetSize,
                scale: scale
            )
            
            return await Task.detached(priority: .userInitiated) {
                let request = VNGenerateImageFeaturePrintRequest()
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                
                do {
                    try handler.perform([request])
                    guard let observation = request.results?.first else { return nil }
                    return VisionResult(featurePrint: observation, byteCount: byteCount)
                } catch {
                    return nil
                }
            }.value
        } catch {
            return nil
        }
    }

    private nonisolated func groupSimilarCandidates(
        _ candidates: [FeaturePrintCandidate],
        threshold: Float,
        assetMap: [String: PHAsset]
    ) -> (issues: [PhotoIssue], groups: [DuplicateGroup]) {
        guard candidates.count >= 2 else { return ([], []) }

        var parent = Array(0..<candidates.count)
        var rank = Array(repeating: 0, count: candidates.count)

        func find(_ x: Int) -> Int {
            if parent[x] != x {
                parent[x] = find(parent[x])
            }
            return parent[x]
        }

        func union(_ x: Int, _ y: Int) {
            let px = find(x)
            let py = find(y)
            guard px != py else { return }

            if rank[px] < rank[py] {
                parent[px] = py
            } else if rank[px] > rank[py] {
                parent[py] = px
            } else {
                parent[py] = px
                rank[px] += 1
            }
        }

        let distanceThreshold = 1.0 - threshold

        for i in 0..<candidates.count {
            for j in (i + 1)..<candidates.count {
                var distance: Float = 0
                do {
                    try candidates[i].featurePrint.computeDistance(&distance, to: candidates[j].featurePrint)
                    if distance <= distanceThreshold {
                        union(i, j)
                    }
                } catch {
                    continue
                }
            }
        }

        var groupMap: [Int: [Int]] = [:]
        for i in 0..<candidates.count {
            let root = find(i)
            groupMap[root, default: []].append(i)
        }

        var groups: [DuplicateGroup] = []
        var issues: [PhotoIssue] = []

        for (_, memberIndices) in groupMap where memberIndices.count >= 2 {
            let members = memberIndices.map { candidates[$0] }
            let sortedMembers = sortByOriginalPriority(members)
            let originalId = sortedMembers[0].assetId
            let potentialSavings = sortedMembers.dropFirst().reduce(Int64(0)) { $0 + $1.byteCount }

            let groupId = "similar:\(UUID().uuidString.prefix(8))"
            let group = DuplicateGroup(
                id: groupId,
                assetIdentifiers: sortedMembers.map { $0.assetId },
                suggestedOriginalId: originalId,
                similarity: Double(threshold),
                potentialSavings: potentialSavings
            )
            groups.append(group)

            for member in sortedMembers.dropFirst() {
                guard let asset = assetMap[member.assetId] else { continue }
                let issue = PhotoIssue(
                    asset: asset,
                    issueType: .duplicate,
                    severity: .info,
                    metadata: IssueMetadata(
                        fileSize: member.byteCount,
                        duplicateGroupId: groupId
                    )
                )
                issues.append(issue)
            }
        }

        return (issues, groups)
    }

    private nonisolated func sortByOriginalPriority(_ members: [FeaturePrintCandidate]) -> [FeaturePrintCandidate] {
        members.sorted { lhs, rhs in
            if lhs.resolution != rhs.resolution {
                return lhs.resolution > rhs.resolution
            }
            if lhs.byteCount != rhs.byteCount {
                return lhs.byteCount > rhs.byteCount
            }
            let lhsDate = lhs.creationDate ?? .distantFuture
            let rhsDate = rhs.creationDate ?? .distantFuture
            if lhsDate != rhsDate {
                return lhsDate < rhsDate
            }
            return lhs.assetId < rhs.assetId
        }
    }
}

// MARK: - PHAsset Extension

extension PHAsset {
    static func asset(withIdentifier identifier: String) -> PHAsset? {
        let result = PHAsset.fetchAssets(
            withLocalIdentifiers: [identifier],
            options: nil
        )
        return result.firstObject
    }
}

// MARK: - Array Extension

extension Array {
    nonisolated func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
