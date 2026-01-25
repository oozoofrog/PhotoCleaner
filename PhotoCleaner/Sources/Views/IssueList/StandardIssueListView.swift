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
                IssueInfoHeader(issueType: issueType)

                IssuePhotoGrid(
                    issues: sortedIssues,
                    isSelectionMode: isSelectionMode,
                    selectedIssues: selectedIssues,
                    toggleSelection: toggleSelection,
                    selectIssue: selectIssue
                )
            }
        }
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
