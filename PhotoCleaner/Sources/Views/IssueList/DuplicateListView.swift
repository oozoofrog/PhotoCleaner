//
//  DuplicateListView.swift
//  PhotoCleaner
//
//  중복 사진 목록 화면 - 그룹 관리 지원
//

import SwiftUI

struct DuplicateListView: View {
    let issues: [PhotoIssue]
    let duplicateGroups: [DuplicateGroup]

    @Environment(\.photoAssetService) private var photoAssetService
    @State private var selectedIssues: Set<String> = []
    @State private var isSelectionMode = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var selectedIssue: PhotoIssue?
    @State private var groupToDelete: DuplicateGroup?

    /// 절약 가능 크기순 정렬 (큰 것부터)
    private var sortedGroups: [DuplicateGroup] {
        duplicateGroups.sorted { $0.potentialSavings > $1.potentialSavings }
    }

    /// Issue ID를 Asset ID로 변환 (DuplicateGroupSectionView용)
    private var selectedAssetIds: Set<String> {
        Set(issues.filter { selectedIssues.contains($0.id) }.map(\.assetIdentifier))
    }

    var body: some View {
        Group {
            if issues.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    VStack(spacing: Spacing.sm) {
                        issueInfoHeader
                        duplicateGroupsContent
                    }
                    .padding(.top, Spacing.sm)
                }
            }
        }
        .navigationTitle(IssueType.duplicate.displayName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !issues.isEmpty {
                    Button(isSelectionMode ? "완료" : "선택") {
                        withAnimation {
                            isSelectionMode.toggle()
                            if !isSelectionMode {
                                selectedIssues.removeAll()
                            }
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelectionMode && !selectedIssues.isEmpty {
                selectionToolbar
            }
        }
        .confirmationDialog(
            deleteConfirmationTitle,
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                if groupToDelete != nil {
                    deleteDuplicatesInGroup()
                } else {
                    deleteSelectedPhotos()
                }
            }
            Button("취소", role: .cancel) {
                groupToDelete = nil
            }
        } message: {
            Text(deleteConfirmationMessage)
        }
        .alert(
            "삭제 실패",
            isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )
        ) {
            Button("확인") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
        .navigationDestination(item: $selectedIssue) { issue in
            if let asset = PHAsset.asset(withIdentifier: issue.assetIdentifier) {
                PhotoDetailView(asset: asset, issue: issue)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: IconSize.hero))
                .foregroundStyle(AppColor.success)

            Text("문제 없음")
                .font(Typography.title)
                .foregroundStyle(AppColor.textPrimary)

            Text("\(IssueType.duplicate.displayName) 유형의 문제가 발견되지 않았습니다.")
                .font(Typography.body)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xl)
    }

    // MARK: - Issue Info Header

    private var issueInfoHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label(IssueType.duplicate.displayName, systemImage: IssueType.duplicate.iconName)
                .font(Typography.headline)
                .foregroundStyle(IssueType.duplicate.color)

            Text(IssueType.duplicate.userDescription)
                .font(Typography.subheadline)
                .foregroundStyle(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(AppColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .padding(.horizontal, Spacing.sm)
    }

    // MARK: - Duplicate Groups Content

    private var duplicateGroupsContent: some View {
        VStack(spacing: Spacing.md) {
            ForEach(sortedGroups) { group in
                DuplicateGroupSectionView(
                    group: group,
                    selectedIds: selectedAssetIds,  // Asset IDs, NOT issue IDs
                    isSelectionMode: isSelectionMode
                ) { assetId in
                    // Convert asset ID back to issue ID
                    if let issue = issues.first(where: { $0.assetIdentifier == assetId }) {
                        if isSelectionMode {
                            toggleSelection(issue.id)
                        } else {
                            selectedIssue = issue
                        }
                    }
                } onDeleteDuplicates: {
                    groupToDelete = group
                    showDeleteConfirmation = true
                }
            }
        }
        .padding(.horizontal, Spacing.sm)
    }

    // MARK: - Selection Toolbar

    private var selectionToolbar: some View {
        SelectionToolbar(
            selectedCount: selectedIssues.count,
            totalCount: issues.count,
            onSelectAll: { selectedIssues = Set(issues.map(\.id)) },
            onDeselectAll: { selectedIssues.removeAll() },
            onDelete: { showDeleteConfirmation = true }
        )
    }

    // MARK: - Delete Confirmation

    private var deleteConfirmationTitle: String {
        groupToDelete != nil ? "중복 사진 삭제" : "선택한 사진 삭제"
    }

    private var deleteConfirmationMessage: String {
        if let group = groupToDelete {
            let count = group.duplicateAssetIdentifiers.count
            return "\(count)장의 중복 사진을 삭제할까요?\n원본은 유지됩니다."
        }
        return "\(selectedIssues.count)장의 사진을 삭제할까요?\n삭제된 사진은 '최근 삭제된 항목'으로 이동됩니다."
    }

    // MARK: - Actions

    private func toggleSelection(_ id: String) {
        if selectedIssues.contains(id) {
            selectedIssues.remove(id)
        } else {
            selectedIssues.insert(id)
        }
    }

    private func deleteSelectedPhotos() {
        guard !isDeleting else { return }
        isDeleting = true

        Task {
            deleteError = nil
            defer { isDeleting = false }

            let identifiersToDelete = issues
                .filter { selectedIssues.contains($0.id) }
                .map(\.assetIdentifier)

            do {
                try await photoAssetService.deleteAssets(withIdentifiers: identifiersToDelete)
                selectedIssues.removeAll()
                isSelectionMode = false
            } catch {
                deleteError = error.localizedDescription
            }
        }
    }

    private func deleteDuplicatesInGroup() {
        guard let group = groupToDelete, !isDeleting else { return }
        isDeleting = true

        Task {
            deleteError = nil
            defer {
                isDeleting = false
                groupToDelete = nil
            }

            let identifiersToDelete = group.duplicateAssetIdentifiers

            do {
                try await photoAssetService.deleteAssets(withIdentifiers: identifiersToDelete)
            } catch {
                deleteError = error.localizedDescription
            }
        }
    }
}

#if DEBUG
import Photos

#Preview("DuplicateListView") {
    NavigationStack {
        DuplicateListView(
            issues: PreviewSampleData.duplicateIssues,
            duplicateGroups: PreviewSampleData.duplicateGroups
        )
        .environment(\.photoAssetService, PreviewPhotoAssetService.shared)
    }
}
#endif
