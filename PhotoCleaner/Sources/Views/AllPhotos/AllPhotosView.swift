//
//  AllPhotosView.swift
//  PhotoCleaner
//

import SwiftUI
import Photos

struct AllPhotosView: View {
    @Environment(\.photoAssetService) private var photoAssetService
    @State private var assets: [PHAsset] = []
    @State private var selectedAssets: Set<String> = []
    @State private var isSelectionMode = false
    @State private var isLoading = true
    @State private var showDeleteConfirmation = false
    @State private var deleteError: String?
    @State private var isDeleting = false
    @State private var selectedAssetIdentifier: String?

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if assets.isEmpty {
                emptyStateView
            } else {
                photoGridContent
            }
        }
        .navigationTitle("전체 사진")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !assets.isEmpty {
                    Button(isSelectionMode ? "완료" : "선택") {
                        withAnimation {
                            isSelectionMode.toggle()
                            if !isSelectionMode {
                                selectedAssets.removeAll()
                            }
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isSelectionMode && !selectedAssets.isEmpty {
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
            Text("\(selectedAssets.count)장의 사진을 삭제할까요?\n삭제된 사진은 '최근 삭제된 항목'으로 이동됩니다.")
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
        .navigationDestination(item: $selectedAssetIdentifier) { identifier in
            if let asset = PHAsset.asset(withIdentifier: identifier) {
                PhotoDetailView(asset: asset)
            }
        }
        .task {
            await loadAllPhotos()
        }
    }

    // MARK: - Views

    private var loadingView: some View {
        VStack(spacing: Spacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
            Text("사진을 불러오는 중...")
                .font(Typography.body)
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: IconSize.hero))
                .foregroundStyle(AppColor.textTertiary)

            Text("사진 없음")
                .font(Typography.title)
                .foregroundStyle(AppColor.textPrimary)

            Text("사진첩에 사진이 없습니다.")
                .font(Typography.body)
                .foregroundStyle(AppColor.textSecondary)
        }
        .padding(Spacing.xl)
    }

    private var photoGridContent: some View {
        ScrollView {
            VStack(spacing: Spacing.sm) {
                photoCountHeader

                JustifiedPhotoGrid(
                    targetRowHeight: GridLayout.rowHeight,
                    spacing: Spacing.xs
                ) {
                    ForEach(assets, id: \.localIdentifier) { asset in
                        AssetThumbnailView(
                            asset: asset,
                            isSelected: selectedAssets.contains(asset.localIdentifier),
                            isSelectionMode: isSelectionMode
                        ) {
                            if isSelectionMode {
                                toggleSelection(asset.localIdentifier)
                            } else {
                                selectedAssetIdentifier = asset.localIdentifier
                            }
                        }
                        .photoAspectRatio(aspectRatio(for: asset))
                    }
                }
                .padding(.horizontal, Spacing.sm)
            }
            .padding(.top, Spacing.sm)
        }
    }

    private var photoCountHeader: some View {
        HStack {
            Text("\(assets.count)장의 사진")
                .font(Typography.subheadline)
                .foregroundStyle(AppColor.textSecondary)
            Spacer()
        }
        .padding(.horizontal, Spacing.md)
    }

    private var selectionToolbar: some View {
        HStack {
            Button {
                if selectedAssets.count == assets.count {
                    selectedAssets.removeAll()
                } else {
                    selectedAssets = Set(assets.map(\.localIdentifier))
                }
            } label: {
                Text(selectedAssets.count == assets.count ? "전체 해제" : "전체 선택")
            }

            Spacer()

            Text("\(selectedAssets.count)장 선택됨")
                .font(Typography.caption)
                .foregroundStyle(AppColor.textSecondary)

            Spacer()

            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
        .padding(Spacing.md)
        .background(.ultraThinMaterial)
    }

    // MARK: - Methods

    private func aspectRatio(for asset: PHAsset) -> CGFloat {
        guard asset.pixelHeight > 0 else { return 1.0 }
        return CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
    }

    private func toggleSelection(_ id: String) {
        if selectedAssets.contains(id) {
            selectedAssets.remove(id)
        } else {
            selectedAssets.insert(id)
        }
    }

    private func loadAllPhotos() async {
        let sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let loadedAssets = photoAssetService.fetchAllPhotoAssets(sortedBy: sortDescriptors)
        assets = loadedAssets
        isLoading = false
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

        let identifiersToDelete = Array(selectedAssets)

        do {
            try await photoAssetService.deleteAssets(withIdentifiers: identifiersToDelete)
            assets.removeAll { selectedAssets.contains($0.localIdentifier) }
            selectedAssets.removeAll()
            isSelectionMode = false
        } catch {
            deleteError = error.localizedDescription
        }
    }
}

// MARK: - Preview

#Preview("All Photos") {
    NavigationStack {
        AllPhotosView()
    }
}
