//
//  DashboardViewModel.swift
//  PhotoCleaner
//
//  대시보드 화면의 상태 관리
//

import SwiftUI
import Photos

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
    private(set) var currentLargeFileSizeOption: LargeFileSizeOption = .mb10
    private var currentScanTask: Task<Void, Never>?

    let permissionService: PhotoPermissionService
    private let scanService = PhotoScanService()

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

    /// Phase 1에서 표시할 문제 유형들
    var displayIssueTypes: [IssueType] {
        [.downloadFailed, .corrupted, .screenshot, .largeFile]
    }

    // MARK: - Initialization

    init(permissionService: PhotoPermissionService) {
        self.permissionService = permissionService
        updateAppState()
    }

    convenience init() {
        self.init(permissionService: PhotoPermissionService())
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

    /// 전체 검사 시작
    func startScan() async {
        guard permissionService.status.canAccess else {
            appState = .error("사진 접근 권한이 필요합니다.")
            return
        }

        appState = .scanning
        scanProgress = ScanProgress(phase: .preparing, current: 0, total: 0)

        do {
            let result = try await scanService.scanAll { @MainActor [weak self] progress in
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

        do {
            let result = try await scanService.scan(for: issueTypes) { @MainActor [weak self] progress in
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
}
