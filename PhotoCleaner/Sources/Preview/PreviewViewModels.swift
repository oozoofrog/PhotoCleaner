//
//  PreviewViewModels.swift
//  PhotoCleaner
//
//  Preview용 ViewModel 팩토리 메서드
//

#if DEBUG
import SwiftUI

extension DashboardViewModel {
    /// Preview용 factory - 권한 허용, 스캔 결과 있음
    @MainActor
    static func previewReady() -> DashboardViewModel {
        let vm = DashboardViewModel(
            photoAssetService: PreviewPhotoAssetService.shared
        )
        vm.setPreviewState(
            appState: .ready,
            scanResult: PreviewSampleData.normalScanResult
        )
        return vm
    }

    @MainActor
    static func previewScanning() -> DashboardViewModel {
        let vm = DashboardViewModel(
            photoAssetService: PreviewPhotoAssetService.shared
        )
        vm.setPreviewState(
            appState: .scanning,
            scanProgress: ScanProgress(phase: .scanning, current: 45, total: 100),
            liveIssues: Array(PreviewSampleData.screenshots.prefix(2)),
            liveSummaries: [.screenshot: 2]
        )
        return vm
    }

    @MainActor
    static func previewEmpty() -> DashboardViewModel {
        let vm = DashboardViewModel(
            photoAssetService: PreviewPhotoAssetService.shared
        )
        vm.setPreviewState(
            appState: .ready,
            scanResult: PreviewSampleData.emptyScanResult
        )
        return vm
    }

    @MainActor
    static func previewNeedsPermission() -> DashboardViewModel {
        let vm = DashboardViewModel(
            photoAssetService: PreviewPhotoAssetService.shared
        )
        vm.setPreviewState(appState: .needsPermission)
        return vm
    }

    @MainActor
    static func previewError() -> DashboardViewModel {
        let vm = DashboardViewModel(
            photoAssetService: PreviewPhotoAssetService.shared
        )
        vm.setPreviewState(appState: .error("스캔 중 오류가 발생했습니다."))
        return vm
    }
}
#endif
