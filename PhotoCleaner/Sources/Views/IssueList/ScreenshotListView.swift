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
                IssueInfoHeader(issueType: .screenshot)

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
        .onChange(of: issues) { _, newIssues in
            groupedByDate = groupIssuesByDate(newIssues)
        }
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
            IssuePhotoGrid(
                issues: filteredIssues,
                isSelectionMode: isSelectionMode,
                selectedIssues: selectedIssues,
                toggleSelection: toggleSelection,
                selectIssue: selectIssue
            )
        }
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
