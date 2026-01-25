//
//  StandardIssueListView.swift
//  PhotoCleaner
//
//  기본 이슈 목록 화면 - 특별한 필터/그룹핑 없음
//

import SwiftUI
import Photos

struct StandardIssueListView: View {
    let issueType: IssueType
    let issues: [PhotoIssue]

    @Bindable var settings = AppSettings.shared

    private var sortedIssues: [PhotoIssue] {
        switch settings.sortOrder {
        case .date:
            return issues
        case .size:
            return issues.sorted { ($0.metadata.fileSize ?? 0) > ($1.metadata.fileSize ?? 0) }
        case .name:
            return issues  // Fallback to date order
        }
    }

    var body: some View {
        BaseIssueListView(issueType: issueType, issues: issues) {
            isSelectionMode, selectedIssues, toggleSelection, selectIssue in

            VStack(spacing: Spacing.sm) {
                issueInfoHeader

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
            Label(issueType.displayName, systemImage: issueType.iconName)
                .font(Typography.headline)
                .foregroundStyle(issueType.color)

            Text(issueType.userDescription)
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
#Preview("StandardIssueListView - Corrupted") {
    NavigationStack {
        StandardIssueListView(
            issueType: .corrupted,
            issues: [PhotoIssue.previewCorrupted]
        )
        .environment(\.photoAssetService, PreviewPhotoAssetService.shared)
    }
}
#endif
