//
//  DashboardViewModel.swift
//  PhotoCleaner
//
//  대시보드 화면의 상태 관리
//

import SwiftUI
import Photos
import SwiftData

/// 앱 전체 상태
enum AppState {
    case needsPermission
    case ready
    case scanning
    case error(String)
}

/// 대시보드 ViewModel
@MainActor
@Observable
final class DashboardViewModel {

    // MARK: - Properties

    private(set) var appState: AppState = .needsPermission
    private(set) var scanProgress: ScanProgress?
    private(set) var scanResult: ScanResult?
    private(set) var lastScanDate: Date?
    var currentLargeFileSizeOption: LargeFileSizeOption = .mb10
    private var currentScanTask: Task<Void, Never>?

    // MARK: - Streaming State (실시간 스캔 상태)

    /// 실시간 발견된 이슈 (스캔 중)
    private(set) var liveIssues: [PhotoIssue] = []

    /// 실시간 발견된 중복 그룹 (스캔 중)
    private(set) var liveDuplicateGroups: [DuplicateGroup] = []

    /// 실시간 요약 (스캔 중)
    private(set) var liveSummaries: [IssueType: Int] = [:]

    /// 스캔 태스크 참조
    private var scanStreamTask: Task<Void, Never>?

    /// 스캔이 취소되었는지 여부
    private(set) var scanWasCancelled: Bool = false

    /// 취소 시 처리된 사진 수
    private(set) var cancelledProcessedCount: Int = 0

    let permissionService: PhotoPermissionService
    private let scanService: PhotoScanService
    private let cacheStore: PhotoCacheStoreProtocol?
    private let syncService: PhotoLibrarySyncService?

    // MARK: - Computed Properties

    var totalPhotoCount: Int {
        scanResult?.totalPhotos ?? 0
    }

    var totalIssueCount: Int {
        scanResult?.totalIssueCount ?? 0
    }

    var isScanning: Bool {
        if case .scanning = appState { return true }
        return false
    }

    var hasScanned: Bool {
        scanResult != nil
    }

    /// 실시간 총 이슈 개수 (스캔 중)
    var liveIssueCount: Int {
        liveIssues.count
    }

    /// 실시간 중복 그룹 개수 (스캔 중)
    var liveDuplicateGroupCount: Int {
        liveDuplicateGroups.count
    }

    /// 현재 표시할 이슈 개수 (스캔 중이면 live, 아니면 result)
    var displayIssueCount: Int {
        isScanning ? liveIssueCount : totalIssueCount
    }

    /// 현재 표시할 특정 타입 이슈 개수
    func displayCount(for issueType: IssueType) -> Int {
        if isScanning {
            return liveSummaries[issueType] ?? 0
        } else {
            return summary(for: issueType)?.count ?? 0
        }
    }

    /// Phase 1에서 표시할 문제 유형들
    var displayIssueTypes: [IssueType] {
        [.downloadFailed, .corrupted, .screenshot, .largeFile]
    }

    // MARK: - Initialization

    init(
        permissionService: PhotoPermissionService = PhotoPermissionService(),
        photoAssetService: some PhotoAssetService = SystemPhotoAssetService(),
        cacheStore: PhotoCacheStoreProtocol? = nil
    ) {
        self.permissionService = permissionService
        self.scanService = PhotoScanService(photoAssetService: photoAssetService)
        self.cacheStore = cacheStore
        if let cacheStore = cacheStore {
            self.syncService = PhotoLibrarySyncService(
                cacheStore: cacheStore,
                libraryProvider: RealPhotoLibraryProvider()
            )
        } else {
            self.syncService = nil
        }
        updateAppState()
    }

    convenience init(cacheStore: PhotoCacheStoreProtocol) {
        self.init(
            permissionService: PhotoPermissionService(),
            photoAssetService: SystemPhotoAssetService(),
            cacheStore: cacheStore
        )
    }

    // MARK: - Public Methods

    /// 앱 상태 업데이트
    func updateAppState() {
        permissionService.updateStatus()

        if permissionService.status.canAccess {
            appState = .ready
        } else if permissionService.status == .notDetermined {
            appState = .needsPermission
        } else {
            appState = .needsPermission
        }
    }

    /// 권한 요청
    func requestPermission() async {
        await permissionService.requestAuthorization()
        updateAppState()
    }

    /// 캐시와 사진 라이브러리 동기화
    func performInitialSync() async {
        guard let syncService = syncService else { return }
        await syncService.performFullSync()
        
        if AppSettings.shared.autoScanEnabled {
            await startScan()
        }
    }

    /// 전체 검사 시작 (스트리밍 방식)
    func startScan() async {
        guard permissionService.status.canAccess else {
            appState = .error("사진 접근 권한이 필요합니다.")
            return
        }

        // 기존 스캔 취소
        cancelScan()

        // 상태 초기화
        appState = .scanning
        scanProgress = ScanProgress(phase: .preparing, current: 0, total: 0)
        liveIssues = []
        liveDuplicateGroups = []
        liveSummaries = [:]
        scanWasCancelled = false
        cancelledProcessedCount = 0

        // 설정 가져오기
        let duplicateMode = AppSettings.shared.duplicateDetectionMode
        let similarityThreshold = AppSettings.shared.similarityThreshold

        // 스트리밍 스캔 시작
        let stream = await scanService.scanAllStreaming(
            duplicateDetectionMode: duplicateMode,
            similarityThreshold: similarityThreshold
        )

        scanStreamTask = Task { [weak self] in
            for await update in stream {
                guard let self = self else { break }
                await self.handleScanUpdate(update)
            }
        }
    }

    /// 스캔 업데이트 처리
    @MainActor
    private func handleScanUpdate(_ update: ScanUpdate) {
        switch update {
        case .progress(let progress):
            self.scanProgress = progress

        case .issueFound(let issue):
            // 중복 이슈는 별도 처리 (duplicateGroupFound에서 처리)
            if issue.issueType != .duplicate {
                self.liveIssues.append(issue)
            }

        case .summaryUpdated(let issueType, let count):
            self.liveSummaries[issueType] = count

        case .duplicateGroupFound(let group):
            self.liveDuplicateGroups.append(group)
            // 중복 이슈 카운트 업데이트
            let duplicateCount = group.assetIdentifiers.count - 1 // 원본 제외
            self.liveSummaries[.duplicate, default: 0] += duplicateCount

        case .completed(let result):
            self.scanResult = result
            self.lastScanDate = Date()
            self.appState = .ready
            self.scanProgress = nil
            self.scanStreamTask = nil

        case .cancelled(let partialResult):
            self.scanWasCancelled = true
            self.cancelledProcessedCount = scanProgress?.current ?? 0
            if let partial = partialResult {
                self.scanResult = partial
            }
            self.appState = .ready
            self.scanProgress = nil
            self.scanStreamTask = nil

        case .failed(let error):
            self.appState = .error("검사 중 오류가 발생했습니다: \(error.localizedDescription)")
            self.scanProgress = nil
            self.scanStreamTask = nil
        }
    }

    /// 스캔 취소
    /// Task 취소만으로 충분 - AsyncStream의 onTermination이 내부 Task를 취소하므로
    /// 별도의 scanService.cancelScan() 호출 불필요
    func cancelScan() {
        scanStreamTask?.cancel()
        scanStreamTask = nil
    }

    /// 전체 검사 시작 (레거시 - 하위호환성 유지)
    @available(*, deprecated, message: "Use startScan() instead")
    func startScanLegacy() async {
        guard permissionService.status.canAccess else {
            appState = .error("사진 접근 권한이 필요합니다.")
            return
        }

        appState = .scanning
        scanProgress = ScanProgress(phase: .preparing, current: 0, total: 0)

        // 설정 가져오기
        let duplicateMode = AppSettings.shared.duplicateDetectionMode
        let similarityThreshold = AppSettings.shared.similarityThreshold

        do {
            let result = try await scanService.scanAll(
                duplicateDetectionMode: duplicateMode,
                similarityThreshold: similarityThreshold
            ) { @MainActor [weak self] progress in
                self?.scanProgress = progress
            }

            scanResult = result
            lastScanDate = Date()
            appState = .ready
        } catch {
            appState = .error("검사 중 오류가 발생했습니다: \(error.localizedDescription)")
        }

        scanProgress = nil
    }

    /// 특정 유형만 검사
    func scan(for issueTypes: [IssueType]) async {
        guard permissionService.status.canAccess else { return }

        appState = .scanning
        scanProgress = ScanProgress(phase: .preparing, current: 0, total: 0)

        // 설정 가져오기
        let duplicateMode = AppSettings.shared.duplicateDetectionMode
        let similarityThreshold = AppSettings.shared.similarityThreshold

        do {
            let result = try await scanService.scan(
                for: issueTypes,
                duplicateDetectionMode: duplicateMode,
                similarityThreshold: similarityThreshold
            ) { @MainActor [weak self] progress in
                self?.scanProgress = progress
            }

            scanResult = result
            lastScanDate = Date()
            appState = .ready
        } catch {
            appState = .error("검사 중 오류가 발생했습니다.")
        }

        scanProgress = nil
    }

    func summary(for type: IssueType) -> IssueSummary? {
        scanResult?.summary(for: type)
    }

    func issues(for type: IssueType) -> [PhotoIssue] {
        scanResult?.issues(for: type) ?? []
    }

    var formattedLastScanDate: String? {
        guard let date = lastScanDate else { return nil }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = .current
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    var duplicateGroups: [DuplicateGroup] {
        scanResult?.duplicateGroups ?? []
    }

    var duplicateSummary: (groupCount: Int, duplicateCount: Int, potentialSavings: Int64) {
        scanResult?.duplicateSummary ?? (0, 0, 0)
    }

    var hasDuplicates: Bool {
        !duplicateGroups.isEmpty
    }

    var formattedPotentialSavings: String {
        ByteCountFormatter.string(fromByteCount: duplicateSummary.potentialSavings, countStyle: .file)
    }

    func setLargeFileThreshold(_ option: LargeFileSizeOption) async {
        let previousOption = currentLargeFileSizeOption
        currentLargeFileSizeOption = option
        await scanService.setLargeFileThreshold(option)

        if option.bytes > previousOption.bytes {
            filterLargeFilesFromExistingResult(threshold: option.bytes)
        } else {
            currentScanTask?.cancel()
            currentScanTask = Task { await startScan() }
        }
    }

    private func filterLargeFilesFromExistingResult(threshold: Int64) {
        guard let existingResult = scanResult else { return }

        let filteredLargeFiles = existingResult.issues(for: .largeFile).filter {
            ($0.metadata.fileSize ?? 0) >= threshold
        }

        let otherIssues = existingResult.issues.filter { $0.issueType != .largeFile }
        let mergedIssues = otherIssues + filteredLargeFiles

        let filteredSize = filteredLargeFiles.reduce(Int64(0)) { $0 + ($1.metadata.fileSize ?? 0) }
        let otherSummaries = existingResult.summaries.filter { $0.issueType != .largeFile }
        let newLargeFileSummary = IssueSummary(
            issueType: .largeFile,
            count: filteredLargeFiles.count,
            totalSize: filteredSize
        )

        scanResult = ScanResult(
            totalPhotos: existingResult.totalPhotos,
            issues: mergedIssues,
            summaries: otherSummaries + [newLargeFileSummary],
            duplicateGroups: existingResult.duplicateGroups,
            scannedAt: existingResult.scannedAt
        )
    }

    func clearCache() async {
        await scanService.clearCache()
        scanResult = nil
        lastScanDate = nil
    }
}
