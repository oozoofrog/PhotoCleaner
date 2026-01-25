//
//  BaseIssueListView.swift
//  PhotoCleaner
//
//  문제 목록 공통 뷰 - 선택, 삭제, 네비게이션 로직 공유
//

import SwiftUI
import Photos

struct BaseIssueListView<Content: View>: View {
    let issueType: IssueType
    let issues: [PhotoIssue]

    // BaseIssueListView OWNS the state
    @State private var selectedIssues: Set<String> = []
    @State private var isSelectionMode = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var selectedIssue: PhotoIssue?

    @Environment(\.photoAssetService) private var photoAssetService

    // Content receives state via closure parameters
    @ViewBuilder let content: (
        _ isSelectionMode: Bool,
        _ selectedIssues: Set<String>,
        _ toggleSelection: @escaping (String) -> Void,
        _ selectIssue: @escaping (PhotoIssue) -> Void
    ) -> Content

    var body: some View {
        Group {
            if issues.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    content(
                        isSelectionMode,
                        selectedIssues,
                        toggleSelection,
                        { selectedIssue = $0 }
                    )
                    .padding(.top, Spacing.sm)
                }
            }
        }
        .navigationTitle(issueType.displayName)
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
            "선택한 사진 삭제",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                deleteSelectedPhotos()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("\(selectedIssues.count)장의 사진을 삭제할까요?\n삭제된 사진은 '최근 삭제된 항목'으로 이동됩니다.")
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

            Text("\(issueType.displayName) 유형의 문제가 발견되지 않았습니다.")
                .font(Typography.body)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xl)
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
            await performDeletion()
        }
    }

    private func performDeletion() async {
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
