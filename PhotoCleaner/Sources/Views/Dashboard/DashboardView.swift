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

                case .ready:
                    dashboardContent

                case .scanning:
                    ScanningView(progress: viewModel.scanProgress)

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
                    onScan: {
                        Task { await viewModel.startScan() }
                    },
                    onViewAllPhotos: {
                        showAllPhotos = true
                    }
                )

                if viewModel.hasScanned {
                    issueCardsSection

                    if viewModel.hasDuplicates {
                        duplicateSection
                    }
                }
            }
            .padding(Spacing.md)
        }
        .background(AppColor.backgroundGrouped)
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
                        count: viewModel.summary(for: issueType)?.count ?? 0
                    ) {
                        selectedIssueType = issueType
                    }
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

            DuplicateCard(
                groupCount: viewModel.duplicateSummary.groupCount,
                duplicateCount: viewModel.duplicateSummary.duplicateCount,
                potentialSavings: viewModel.formattedPotentialSavings
            ) {
                selectedIssueType = .duplicate
            }
        }
    }
}

struct DuplicateCard: View {
    let groupCount: Int
    let duplicateCount: Int
    let potentialSavings: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Image(systemName: "square.on.square")
                            .font(.system(size: IconSize.lg))
                            .foregroundStyle(AppColor.primary)

                        Text("중복 그룹 \(groupCount)개")
                            .font(Typography.headline)
                            .foregroundStyle(AppColor.textPrimary)
                    }

                    Text("\(duplicateCount)장 정리 시 \(potentialSavings) 확보")
                        .font(Typography.subheadline)
                        .foregroundStyle(AppColor.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(AppColor.textTertiary)
            }
            .padding(Spacing.md)
            .background(AppColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let totalPhotos: Int
    let totalIssues: Int
    let lastScanDate: String?
    let isScanning: Bool
    let onScan: () -> Void
    var onViewAllPhotos: (() -> Void)?

    var body: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("전체 요약")
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.textSecondary)

                    if totalPhotos > 0 {
                        Button {
                            onViewAllPhotos?()
                        } label: {
                            HStack(spacing: Spacing.xs) {
                                Text("\(totalPhotos.formatted())장")
                                    .font(Typography.headline)
                                    .foregroundStyle(AppColor.primary)
                                Text("중 \(totalIssues)장에 문제 발견")
                                    .font(Typography.headline)
                                    .foregroundStyle(AppColor.textPrimary)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: IconSize.sm))
                                    .foregroundStyle(AppColor.textTertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("검사를 시작해 주세요")
                            .font(Typography.headline)
                            .foregroundStyle(AppColor.textPrimary)
                    }

                    if let lastScan = lastScanDate {
                        Text("마지막 검사: \(lastScan)")
                            .font(Typography.caption)
                            .foregroundStyle(AppColor.textTertiary)
                    }
                }

                Spacer()

                if totalIssues > 0 {
                    Text("\(totalIssues)")
                        .font(Typography.largeNumber)
                        .foregroundStyle(AppColor.warning)
                }
            }

            Button(action: onScan) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text(totalPhotos > 0 ? "다시 검사하기" : "검사 시작하기")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary)
            .disabled(isScanning)
        }
        .padding(Spacing.lg)
        .background(AppColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
    }
}

// MARK: - Issue Card

struct IssueCard: View {
    let issueType: IssueType
    let count: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // 아이콘과 개수
                HStack {
                    Image(systemName: issueType.iconName)
                        .font(.system(size: IconSize.lg))
                        .foregroundStyle(issueType.color)

                    Spacer()

                    if count > 0 {
                        Text("\(count)")
                            .font(Typography.mediumNumber)
                            .foregroundStyle(issueType.color)
                    }
                }

                // 이름
                Text(issueType.displayName)
                    .font(Typography.subheadline)
                    .foregroundStyle(AppColor.textPrimary)

                // 상태
                Text(count > 0 ? "\(count)장 발견" : "문제 없음")
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Permission Request View

struct PermissionRequestView: View {
    @Bindable var viewModel: DashboardViewModel

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // 아이콘
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: IconSize.hero))
                .foregroundStyle(AppColor.primary)

            // 제목
            Text("사진 접근 권한이 필요해요")
                .font(Typography.title)
                .foregroundStyle(AppColor.textPrimary)

            // 설명
            VStack(spacing: Spacing.sm) {
                Text("PhotoCleaner가 사진첩의 문제를")
                Text("찾고 정리하려면 사진 접근 권한이 필요합니다.")
            }
            .font(Typography.body)
            .foregroundStyle(AppColor.textSecondary)
            .multilineTextAlignment(.center)

            // 안내 사항
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label("사진은 기기에서만 분석됩니다", systemImage: "lock.shield")
                Label("외부로 전송되지 않습니다", systemImage: "icloud.slash")
            }
            .font(Typography.caption)
            .foregroundStyle(AppColor.textTertiary)
            .padding(Spacing.md)
            .background(AppColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))

            Spacer()

            // 버튼
            VStack(spacing: Spacing.sm) {
                if viewModel.permissionService.status == .denied {
                    Button("설정에서 허용하기") {
                        viewModel.permissionService.openSettings()
                    }
                    .buttonStyle(.primary)
                } else {
                    Button("권한 허용하기") {
                        Task { await viewModel.requestPermission() }
                    }
                    .buttonStyle(.primary)
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
        .padding(Spacing.lg)
    }
}

// MARK: - Scanning View

struct ScanningView: View {
    let progress: ScanProgress?

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)

            Text(progress?.displayText ?? "검사 중...")
                .font(Typography.headline)
                .foregroundStyle(AppColor.textPrimary)

            if let progress = progress, progress.total > 0 {
                ProgressView(value: progress.progress)
                    .progressViewStyle(.linear)
                    .padding(.horizontal, Spacing.xxl)
            }

            Spacer()
        }
    }
}

// MARK: - Error View

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: IconSize.hero))
                .foregroundStyle(AppColor.warning)

            Text("오류가 발생했어요")
                .font(Typography.title)
                .foregroundStyle(AppColor.textPrimary)

            Text(message)
                .font(Typography.body)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button("다시 시도", action: onRetry)
                .buttonStyle(.primary)
                .padding(.horizontal, Spacing.lg)
        }
        .padding(Spacing.lg)
    }
}

// MARK: - Preview

#Preview("Dashboard - Ready") {
    DashboardView(viewModel: DashboardViewModel())
}
