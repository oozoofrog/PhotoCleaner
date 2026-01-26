//
//  IssuePhotoGrid.swift
//  PhotoCleaner
//
//  재사용 가능한 이슈 사진 그리드 컴포넌트
//

import SwiftUI

struct IssuePhotoGrid: View {
    let issues: [PhotoIssue]
    let isSelectionMode: Bool
    let selectedIssues: Set<String>
    let toggleSelection: (String) -> Void
    let selectIssue: (PhotoIssue) -> Void

    var body: some View {
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
