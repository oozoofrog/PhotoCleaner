//
//  LargeFileListView.swift
//  PhotoCleaner
//
//  대용량 파일 목록 화면 - 크기 필터링 지원
//

import SwiftUI
import Photos

struct LargeFileListView: View {
    let issues: [PhotoIssue]
    @Binding var selectedSizeOption: LargeFileSizeOption
    var onLargeFileSizeChange: (@Sendable (LargeFileSizeOption) async -> Void)?

    /// 파일 크기순 정렬 (큰 것부터)
    private var sortedIssues: [PhotoIssue] {
        issues.sorted { ($0.metadata.fileSize ?? 0) > ($1.metadata.fileSize ?? 0) }
    }

    var body: some View {
        BaseIssueListView(issueType: .largeFile, issues: issues) {
            isSelectionMode, selectedIssues, toggleSelection, selectIssue in

            VStack(spacing: Spacing.sm) {
                issueInfoHeader

                SizeFilterPicker(
                    selectedOption: $selectedSizeOption,
                    onOptionChange: onLargeFileSizeChange
                )

                standardPhotoGrid(
                    issues: sortedIssues,
                    isSelectionMode: isSelectionMode,
                    selectedIssues: selectedIssues,
                    toggleSelection: toggleSelection,
                    selectIssue: selectIssue
                )
            }
        }
    }

    // MARK: - Issue Info Header

    private var issueInfoHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label(IssueType.largeFile.displayName, systemImage: IssueType.largeFile.iconName)
                .font(Typography.headline)
                .foregroundStyle(IssueType.largeFile.color)

            Text(IssueType.largeFile.userDescription)
                .font(Typography.subheadline)
                .foregroundStyle(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(AppColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .padding(.horizontal, Spacing.sm)
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
#Preview("LargeFileListView") {
    NavigationStack {
        LargeFileListView(
            issues: PreviewSampleData.largeFiles,
            selectedSizeOption: .constant(.mb10),
            onLargeFileSizeChange: nil
        )
        .environment(\.photoAssetService, PreviewPhotoAssetService.shared)
    }
}
#endif
