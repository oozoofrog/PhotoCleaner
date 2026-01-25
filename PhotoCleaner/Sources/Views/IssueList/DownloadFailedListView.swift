//
//  DownloadFailedListView.swift
//  PhotoCleaner
//
//  다운로드 실패 사진 목록 화면 - 통계 표시 지원
//

import SwiftUI
import Photos

struct DownloadFailedListView: View {
    let issues: [PhotoIssue]

    @State private var cachedStats: [(key: String, value: Int)] = []

    var body: some View {
        BaseIssueListView(issueType: .downloadFailed, issues: issues) {
            isSelectionMode, selectedIssues, toggleSelection, selectIssue in

            VStack(spacing: Spacing.sm) {
                issueInfoHeader

                standardPhotoGrid(
                    issues: issues,
                    isSelectionMode: isSelectionMode,
                    selectedIssues: selectedIssues,
                    toggleSelection: toggleSelection,
                    selectIssue: selectIssue
                )
            }
        }
        .onAppear {
            cachedStats = computeResourceStatistics()
        }
    }

    // MARK: - Issue Info Header with Statistics

    private var issueInfoHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label(IssueType.downloadFailed.displayName, systemImage: IssueType.downloadFailed.iconName)
                .font(Typography.headline)
                .foregroundStyle(IssueType.downloadFailed.color)

            Text(IssueType.downloadFailed.userDescription)
                .font(Typography.subheadline)
                .foregroundStyle(AppColor.textSecondary)

            resourceStatisticsView
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(AppColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .padding(.horizontal, Spacing.sm)
    }

    // MARK: - Resource Statistics

    @ViewBuilder
    private var resourceStatisticsView: some View {
        if !cachedStats.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Divider()
                    .padding(.vertical, Spacing.xs)

                Text("상세 분류")
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textTertiary)

                ForEach(cachedStats.prefix(5), id: \.key) { key, count in
                    HStack {
                        Text(key)
                            .font(Typography.caption)
                            .foregroundStyle(AppColor.textPrimary)
                        Spacer()
                        Text("\(count)장")
                            .font(Typography.caption)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }
            }
        }
    }

    /// 리소스 타입별 통계 계산
    private func computeResourceStatistics() -> [(key: String, value: Int)] {
        let grouped = Dictionary(grouping: issues) { issue in
            issue.metadata.errorMessage ?? "알 수 없음"
        }
        return grouped
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
    }

    // MARK: - Photo Grid

    private func standardPhotoGrid(
        issues: [PhotoIssue],
        isSelectionMode: Bool,
        selectedIssues: Set<String>,
        toggleSelection: @escaping (String) -> Void,
        selectIssue: @escaping (PhotoIssue) -> Void
    ) -> some View {
        JustifiedPhotoGrid(
            targetRowHeight: GridLayout.rowHeight,
            spacing: Spacing.xs
        ) {
            ForEach(issues) { issue in
                PhotoThumbnailView(
                    issue: issue,
                    isSelected: selectedIssues.contains(issue.id),
                    isSelectionMode: isSelectionMode
                ) {
                    if isSelectionMode {
                        toggleSelection(issue.id)
                    } else {
                        selectIssue(issue)
                    }
                }
                .photoAspectRatio(issue.aspectRatio)
            }
        }
        .padding(.horizontal, Spacing.sm)
    }
}

#if DEBUG
#Preview("DownloadFailedListView") {
    NavigationStack {
        DownloadFailedListView(issues: PreviewSampleData.downloadFailed)
            .environment(\.photoAssetService, PreviewPhotoAssetService.shared)
    }
}
#endif
