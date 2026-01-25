//
//  ScreenshotListView.swift
//  PhotoCleaner
//
//  스크린샷 목록 화면 - 날짜 필터링 지원
//

import SwiftUI
import Photos

struct ScreenshotListView: View {
    let issues: [PhotoIssue]

    @Environment(\.photoAssetService) private var photoAssetService
    @State private var selectedDateFilter: DateFilter = .all
    @State private var groupedByDate: [DateFilter: [PhotoIssue]] = [:]

    var body: some View {
        BaseIssueListView(issueType: .screenshot, issues: issues) {
            isSelectionMode, selectedIssues, toggleSelection, selectIssue in

            VStack(spacing: Spacing.sm) {
                issueInfoHeader

                DateFilterPicker(
                    selectedFilter: $selectedDateFilter,
                    counts: Dictionary(uniqueKeysWithValues: groupedByDate.map { ($0.key, $0.value.count) }),
                    totalCount: issues.count
                )

                screenshotContent(
                    isSelectionMode: isSelectionMode,
                    selectedIssues: selectedIssues,
                    toggleSelection: toggleSelection,
                    selectIssue: selectIssue
                )
            }
        }
        .onAppear {
            groupedByDate = groupIssuesByDate(issues)
        }
    }

    // MARK: - Issue Info Header

    private var issueInfoHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label(IssueType.screenshot.displayName, systemImage: IssueType.screenshot.iconName)
                .font(Typography.headline)
                .foregroundStyle(IssueType.screenshot.color)

            Text(IssueType.screenshot.userDescription)
                .font(Typography.subheadline)
                .foregroundStyle(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(AppColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .padding(.horizontal, Spacing.sm)
    }

    // MARK: - Screenshot Content

    @ViewBuilder
    private func screenshotContent(
        isSelectionMode: Bool,
        selectedIssues: Set<String>,
        toggleSelection: @escaping (String) -> Void,
        selectIssue: @escaping (PhotoIssue) -> Void
    ) -> some View {
        let filteredIssues = selectedDateFilter == .all ? issues : (groupedByDate[selectedDateFilter] ?? [])

        if filteredIssues.isEmpty {
            VStack(spacing: Spacing.md) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: IconSize.xl))
                    .foregroundStyle(AppColor.textTertiary)
                Text("해당 기간에 스크린샷이 없습니다")
                    .font(Typography.body)
                    .foregroundStyle(AppColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xxl)
        } else {
            standardPhotoGrid(
                issues: filteredIssues,
                isSelectionMode: isSelectionMode,
                selectedIssues: selectedIssues,
                toggleSelection: toggleSelection,
                selectIssue: selectIssue
            )
        }
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

    // MARK: - Date Grouping

    private func groupIssuesByDate(_ issues: [PhotoIssue]) -> [DateFilter: [PhotoIssue]] {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfWeek = calendar.date(byAdding: .day, value: -7, to: startOfToday)!
        let startOfMonth = calendar.date(byAdding: .day, value: -30, to: startOfToday)!

        var grouped: [DateFilter: [PhotoIssue]] = [:]

        for issue in issues {
            guard let asset = photoAssetService.asset(withIdentifier: issue.assetIdentifier),
                  let creationDate = asset.creationDate else {
                grouped[.older, default: []].append(issue)
                continue
            }

            if creationDate >= startOfToday {
                grouped[.today, default: []].append(issue)
            } else if creationDate >= startOfWeek {
                grouped[.thisWeek, default: []].append(issue)
            } else if creationDate >= startOfMonth {
                grouped[.thisMonth, default: []].append(issue)
            } else {
                grouped[.older, default: []].append(issue)
            }
        }

        return grouped
    }
}

#if DEBUG
#Preview("ScreenshotListView") {
    NavigationStack {
        ScreenshotListView(issues: PreviewSampleData.screenshots)
            .environment(\.photoAssetService, PreviewPhotoAssetService.shared)
    }
}
#endif
