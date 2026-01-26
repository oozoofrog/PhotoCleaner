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
                IssueInfoHeader(issueType: .largeFile)

                SizeFilterPicker(
                    selectedOption: $selectedSizeOption,
                    onOptionChange: onLargeFileSizeChange
                )

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
