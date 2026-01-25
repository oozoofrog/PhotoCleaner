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

struct DuplicateCard: View {
    let groupCount: Int
    let duplicateCount: Int
    let potentialSavings: String
    var isUpdating: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Image(systemName: "square.on.square")
                            .font(.system(size: IconSize.lg))
                            .foregroundStyle(AppColor.primary)

                        HStack(spacing: Spacing.xs) {
                            Text("중복 그룹 ")
                                .font(Typography.headline)
                                .foregroundStyle(AppColor.textPrimary)
                            Text("\(groupCount)")
                                .font(Typography.headline)
                                .foregroundStyle(AppColor.textPrimary)
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.3), value: groupCount)
                            Text("개")
                                .font(Typography.headline)
                                .foregroundStyle(AppColor.textPrimary)
                            if isUpdating {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                        }
                    }

                    HStack(spacing: 0) {
                        Text("\(duplicateCount)")
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3), value: duplicateCount)
                        Text("장 정리 시 \(potentialSavings) 확보")
                    }
                    .font(Typography.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
                }

                Spacer()

                if !isUpdating {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(AppColor.textTertiary)
                }
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
    let scanProgress: ScanProgress?
    var liveIssueCount: Int = 0
    var scanWasCancelled: Bool = false
    var cancelledProcessedCount: Int = 0
    let onScan: () -> Void
    var onCancel: (() -> Void)?
    var onViewAllPhotos: (() -> Void)?

    /// 현재 표시할 이슈 개수
    private var displayIssueCount: Int {
        isScanning ? liveIssueCount : totalIssues
    }

    /// 현재 표시할 사진 개수
    private var displayPhotoCount: Int {
        if isScanning, let progress = scanProgress {
            return progress.total > 0 ? progress.total : totalPhotos
        }
        return totalPhotos
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            // 스캔 중 인라인 프로그레스 바
            if isScanning, let progress = scanProgress, progress.total > 0 {
                VStack(spacing: Spacing.xs) {
                    ProgressView(value: progress.progress)
                        .progressViewStyle(.linear)
                        .tint(AppColor.primary)

                    HStack {
                        Text(progress.displayText)
                            .font(Typography.caption)
                            .foregroundStyle(AppColor.textSecondary)
                        Spacer()
                        Text("\(Int(progress.progress * 100))%")
                            .font(Typography.caption)
                            .foregroundStyle(AppColor.textTertiary)
                    }
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("전체 요약")
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.textSecondary)

                    if displayPhotoCount > 0 || isScanning {
                        Button {
                            onViewAllPhotos?()
                        } label: {
                            HStack(spacing: Spacing.xs) {
                                Text("\(displayPhotoCount.formatted())장")
                                    .font(Typography.headline)
                                    .foregroundStyle(AppColor.primary)
                                Text("중 ")
                                    .font(Typography.headline)
                                    .foregroundStyle(AppColor.textPrimary)
                                // 실시간 이슈 카운트 (애니메이션)
                                Text("\(displayIssueCount)")
                                    .font(Typography.headline)
                                    .foregroundStyle(AppColor.textPrimary)
                                    .contentTransition(.numericText())
                                    .animation(.spring(response: 0.3), value: displayIssueCount)
                                Text("장에 문제 발견")
                                    .font(Typography.headline)
                                    .foregroundStyle(AppColor.textPrimary)
                                if !isScanning {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: IconSize.sm))
                                        .foregroundStyle(AppColor.textTertiary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isScanning)
                    } else {
                        Text("검사를 시작해 주세요")
                            .font(Typography.headline)
                            .foregroundStyle(AppColor.textPrimary)
                    }

                    // 마지막 스캔 날짜 또는 스캔 상태
                    if isScanning {
                        Text("검사 중...")
                            .font(Typography.caption)
                            .foregroundStyle(AppColor.primary)
                    } else if scanWasCancelled {
                        Text("검사가 취소되었습니다 (\(cancelledProcessedCount)장 처리됨)")
                            .font(Typography.caption)
                            .foregroundStyle(AppColor.warning)
                    } else if let lastScan = lastScanDate {
                        Text("마지막 검사: \(lastScan)")
                            .font(Typography.caption)
                            .foregroundStyle(AppColor.textTertiary)
                    }
                }

                Spacer()

                if displayIssueCount > 0 {
                    Text("\(displayIssueCount)")
                        .font(Typography.largeNumber)
                        .foregroundStyle(AppColor.warning)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3), value: displayIssueCount)
                }
            }

            // 스캔/취소 버튼
            if isScanning {
                Button {
                    onCancel?()
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("검사 취소하기")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.destructive)
            } else {
                Button(action: onScan) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text(totalPhotos > 0 ? "다시 검사하기" : "검사 시작하기")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
            }
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
    var isUpdating: Bool = false
    let onTap: () -> Void

    @State private var isAnimating = false

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
                            .contentTransition(.numericText())
                            .scaleEffect(isAnimating ? 1.15 : 1.0)
                            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isAnimating)
                    }
                }

                // 이름
                Text(issueType.displayName)
                    .font(Typography.subheadline)
                    .foregroundStyle(AppColor.textPrimary)

                // 상태
                Group {
                    if isUpdating {
                        HStack(spacing: Spacing.xs) {
                            Text("\(count)장 발견")
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    } else {
                        Text(count > 0 ? "\(count)장 발견" : "문제 없음")
                    }
                }
                .font(Typography.caption)
                .foregroundStyle(AppColor.textSecondary)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .strokeBorder(
                        isAnimating ? issueType.color.opacity(0.3) : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
        .onChange(of: count) { oldValue, newValue in
            // 카운트 증가 시 애니메이션
            if newValue > oldValue && isUpdating {
                withAnimation {
                    isAnimating = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    withAnimation {
                        isAnimating = false
                    }
                }
            }
        }
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
