//
//  DashboardView.swift
//  PhotoCleaner
//
//  메인 대시보드 화면
//

import SwiftUI

struct DashboardView: View {
    @Bindable var viewModel: DashboardViewModel
    @State private var selectedIssueType: IssueType?
    @State private var showSettings = false
    @State private var showAllPhotos = false

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.appState {
                case .needsPermission:
                    PermissionRequestView(viewModel: viewModel)

                case .ready, .scanning:
                    // 스캔 중에도 Dashboard 표시 (실시간 업데이트)
                    dashboardContent

                case .error(let message):
                    ErrorView(message: message) {
                        viewModel.updateAppState()
                    }
                }
            }
            .navigationTitle("PhotoCleaner")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .navigationDestination(item: $selectedIssueType) { issueType in
                issueListView(for: issueType)
            }
            .navigationDestination(isPresented: $showSettings) {
                SettingsView(
                    settings: AppSettings.shared,
                    onClearCache: {
                        Task { await viewModel.clearCache() }
                    }
                )
            }
            .navigationDestination(isPresented: $showAllPhotos) {
                AllPhotosView()
            }
        }
    }

    // MARK: - Issue List Builder

    @ViewBuilder
    private func issueListView(for issueType: IssueType) -> some View {
        if issueType == .largeFile {
            IssueListView(
                issueType: issueType,
                issues: viewModel.issues(for: issueType),
                selectedSizeOption: $viewModel.currentLargeFileSizeOption,
                onLargeFileSizeChange: { @Sendable option in
                    await viewModel.setLargeFileThreshold(option)
                }
            )
        } else if issueType == .duplicate {
            IssueListView(
                issueType: issueType,
                issues: viewModel.issues(for: issueType),
                duplicateGroups: viewModel.duplicateGroups,
                selectedSizeOption: .constant(.mb10)
            )
        } else {
            IssueListView(
                issueType: issueType,
                issues: viewModel.issues(for: issueType),
                selectedSizeOption: .constant(.mb10)
            )
        }
    }

    // MARK: - Dashboard Content

    @ViewBuilder
    private var dashboardContent: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                SummaryCard(
                    totalPhotos: viewModel.totalPhotoCount,
                    totalIssues: viewModel.totalIssueCount,
                    lastScanDate: viewModel.formattedLastScanDate,
                    isScanning: viewModel.isScanning,
                    scanProgress: viewModel.scanProgress,
                    liveIssueCount: viewModel.liveIssueCount,
                    scanWasCancelled: viewModel.scanWasCancelled,
                    cancelledProcessedCount: viewModel.cancelledProcessedCount,
                    onScan: {
                        Task { await viewModel.startScan() }
                    },
                    onCancel: {
                        viewModel.cancelScan()
                    },
                    onViewAllPhotos: {
                        showAllPhotos = true
                    }
                )

                // 스캔 중에도 이슈 카드 표시 (hasScanned 또는 isScanning)
                if viewModel.hasScanned || viewModel.isScanning {
                    issueCardsSection

                    // 중복 섹션 (스캔 중이면 라이브 데이터 사용)
                    if viewModel.isScanning ? viewModel.liveDuplicateGroupCount > 0 : viewModel.hasDuplicates {
                        duplicateSection
                    }
                }
            }
            .padding(Spacing.md)
        }
        .premiumBackground()
        .refreshable {
            await viewModel.startScan()
        }
    }

    // MARK: - Issue Cards Section

    @ViewBuilder
    private var issueCardsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("문제 유형")
                .font(Typography.headline)
                .foregroundStyle(AppColor.textPrimary)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: Spacing.md),
                    GridItem(.flexible(), spacing: Spacing.md)
                ],
                spacing: Spacing.md
            ) {
                ForEach(viewModel.displayIssueTypes) { issueType in
                    IssueCard(
                        issueType: issueType,
                        count: viewModel.displayCount(for: issueType),
                        isUpdating: viewModel.isScanning
                    ) {
                        selectedIssueType = issueType
                    }
                    .disabled(viewModel.isScanning)
                }
            }
        }
    }

    @ViewBuilder
    private var duplicateSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("중복 사진")
                .font(Typography.headline)
                .foregroundStyle(AppColor.textPrimary)

            // 스캔 중이면 라이브 데이터 사용
            let groupCount = viewModel.isScanning
                ? viewModel.liveDuplicateGroupCount
                : viewModel.duplicateSummary.groupCount
            let duplicateCount = viewModel.isScanning
                ? viewModel.liveSummaries[.duplicate] ?? 0
                : viewModel.duplicateSummary.duplicateCount

            DuplicateCard(
                groupCount: groupCount,
                duplicateCount: duplicateCount,
                potentialSavings: viewModel.isScanning ? "계산 중..." : viewModel.formattedPotentialSavings,
                isUpdating: viewModel.isScanning
            ) {
                selectedIssueType = .duplicate
            }
            .disabled(viewModel.isScanning)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Dashboard - Ready") {
    DashboardView(viewModel: .previewReady())
        .environment(\.photoAssetService, PreviewPhotoAssetService.shared)
}

#Preview("Dashboard - Scanning") {
    DashboardView(viewModel: .previewScanning())
        .environment(\.photoAssetService, PreviewPhotoAssetService.shared)
}

#Preview("Dashboard - Empty") {
    DashboardView(viewModel: .previewEmpty())
        .environment(\.photoAssetService, PreviewPhotoAssetService.shared)
}

#Preview("Dashboard - Needs Permission") {
    DashboardView(viewModel: .previewNeedsPermission())
        .environment(\.photoAssetService, PreviewPhotoAssetService.shared)
}

#Preview("Dashboard - Error") {
    DashboardView(viewModel: .previewError())
        .environment(\.photoAssetService, PreviewPhotoAssetService.shared)
}
#endif
