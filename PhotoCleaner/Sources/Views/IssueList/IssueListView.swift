//
//  IssueListView.swift
//  PhotoCleaner
//
//  문제 사진 목록 화면 - 도메인별 뷰로 라우팅
//

import SwiftUI

struct IssueListView: View {
    let issueType: IssueType
    let issues: [PhotoIssue]
    var duplicateGroups: [DuplicateGroup] = []
    @Binding var selectedSizeOption: LargeFileSizeOption
    var onLargeFileSizeChange: (@Sendable (LargeFileSizeOption) async -> Void)?

    var body: some View {
        switch issueType {
        case .screenshot:
            ScreenshotListView(issues: issues)
        case .largeFile:
            LargeFileListView(
                issues: issues,
                selectedSizeOption: $selectedSizeOption,
                onLargeFileSizeChange: onLargeFileSizeChange
            )
        case .duplicate:
            DuplicateListView(issues: issues, duplicateGroups: duplicateGroups)
        case .downloadFailed:
            DownloadFailedListView(issues: issues)
        case .corrupted:
            StandardIssueListView(issueType: .corrupted, issues: issues)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Issue List - Screenshots") {
    NavigationStack {
        IssueListView(
            issueType: .screenshot,
            issues: PreviewSampleData.screenshots,
            selectedSizeOption: .constant(.mb10)
        )
        .environment(\.photoAssetService, PreviewPhotoAssetService.shared)
    }
}

#Preview("Issue List - Empty") {
    NavigationStack {
        IssueListView(
            issueType: .screenshot,
            issues: [],
            selectedSizeOption: .constant(.mb10)
        )
    }
}

#Preview("Issue List - Large Files") {
    NavigationStack {
        IssueListView(
            issueType: .largeFile,
            issues: PreviewSampleData.largeFiles,
            selectedSizeOption: .constant(.mb10)
        )
        .environment(\.photoAssetService, PreviewPhotoAssetService.shared)
    }
}

#Preview("Issue List - Duplicates") {
    NavigationStack {
        IssueListView(
            issueType: .duplicate,
            issues: PreviewSampleData.duplicateIssues,
            duplicateGroups: PreviewSampleData.duplicateGroups,
            selectedSizeOption: .constant(.mb10)
        )
        .environment(\.photoAssetService, PreviewPhotoAssetService.shared)
    }
}
#endif
