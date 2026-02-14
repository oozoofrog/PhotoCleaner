//
//  AllPhotosView.swift
//  PhotoCleaner
//

import SwiftUI
import Photos

struct AllPhotosView: View {
    @Environment(\.photoAssetService) private var photoAssetService
    private let cacheStore: PhotoCacheStoreProtocol?
    private let keywordLocalizationService: KeywordLocalizationService
    @State private var assets: [PHAsset] = []
    @State private var allAssets: [PHAsset] = []
    @State private var keywordSummaries: [KeywordSummaryDTO] = []
    @State private var selectedAssets: Set<String> = []
    @State private var isSelectionMode = false
    @State private var isLoading = true
    @State private var showDeleteConfirmation = false
    @State private var deleteError: String?
    @State private var isDeleting = false
    @State private var selectedAssetIdentifier: String?
    @State private var selectedKeywordFilter: String?

    init(
        cacheStore: PhotoCacheStoreProtocol? = nil,
        initialKeywordFilter: String? = nil,
        keywordLocalizationService: KeywordLocalizationService = KeywordLocalizationService()
    ) {
        self.cacheStore = cacheStore
        self.keywordLocalizationService = keywordLocalizationService
        _selectedKeywordFilter = State(initialValue: initialKeywordFilter)
    }

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
        .task(id: selectedKeywordFilter) {
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

            if isFilterActive {
                Text("\"\(currentKeywordLabel)\" 키워드 결과가 없습니다.")
                    .font(Typography.body)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("사진첩에 사진이 없습니다.")
                    .font(Typography.body)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .padding(Spacing.xl)
    }

    private var photoGridContent: some View {
        ScrollView {
            VStack(spacing: Spacing.sm) {
                keywordFilterBar
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
            let suffix = isFilterActive ? " (필터 적용)" : ""
            Text("\(assets.count)장의 사진\(suffix)")
                .font(Typography.subheadline)
                .foregroundStyle(AppColor.textSecondary)
            Spacer()
        }
        .padding(.horizontal, Spacing.md)
    }

    private var keywordFilterBar: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if !keywordSummaryChips.isEmpty {
                Text("키워드")
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .padding(.horizontal, Spacing.md)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xs) {
                        Button("전체") {
                            selectedKeywordFilter = nil
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            Group {
                                if selectedKeywordFilter == nil {
                                    AppColor.premiumGradient
                                } else {
                                    AppColor.backgroundTertiary
                                }
                            }
                        )
                        .foregroundStyle(selectedKeywordFilter == nil ? AppColor.primaryText : AppColor.textPrimary)
                        .clipShape(Capsule())
                        .overlay(
                                Capsule().stroke(AppColor.separator, lineWidth: selectedKeywordFilter == nil ? 0 : 1)
                        )

                        ForEach(keywordSummaryChips) { summary in
                            let isSelected = summary.keyword == selectedKeywordFilter

                            Button(summary.displayText) {
                                selectedKeywordFilter = isSelected ? nil : summary.keyword
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .background(
                                Group {
                                    if isSelected {
                                        AppColor.premiumGradient
                                    } else {
                                        AppColor.backgroundTertiary
                                    }
                                }
                            )
                            .foregroundStyle(isSelected ? AppColor.primaryText : AppColor.textPrimary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? AppColor.primary : AppColor.separator, lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                }
            }
        }
        .padding(.top, Spacing.sm)
    }

    private var keywordSummaryChips: [KeywordSummaryChip] {
        keywordSummaries
            .prefix(12)
            .map { summary in
                KeywordSummaryChip(
                    id: "\(summary.keyword)|\(summary.languageCode)",
                    keyword: summary.keyword,
                    languageCode: summary.languageCode,
                    displayText: keywordLocalizationService.localizedDisplayKeyword(
                        from: summary.keyword,
                        sourceLanguageCode: summary.languageCode,
                        locale: .current
                    ) + " (\(summary.assetCount))"
                )
            }
    }

    private var isFilterActive: Bool {
        selectedKeywordFilter != nil
    }

    private var currentKeywordLabel: String {
        guard let selectedKeywordFilter else { return "" }
        if let summary = keywordSummaries.first(where: { $0.keyword == selectedKeywordFilter }) {
            return keywordLocalizationService.localizedDisplayKeyword(
                from: summary.keyword,
                sourceLanguageCode: summary.languageCode,
                locale: .current
            )
        }
        return selectedKeywordFilter
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

    private struct KeywordSummaryChip: Identifiable, Hashable {
        let id: String
        let keyword: String
        let languageCode: String
        let displayText: String
    }

    private func toggleSelection(_ id: String) {
        if selectedAssets.contains(id) {
            selectedAssets.remove(id)
        } else {
            selectedAssets.insert(id)
        }
    }

    private func loadAllPhotos() async {
        isLoading = true
        let sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let loadedAssets = photoAssetService.fetchAllPhotoAssets(sortedBy: sortDescriptors)
        allAssets = loadedAssets
        assets = await filteredAssets(from: loadedAssets)

        if let cacheStore {
            keywordSummaries = await cacheStore.fetchKeywordSummary(limit: 24)
        } else {
            keywordSummaries = []
        }

        isLoading = false
    }

    private func filteredAssets(from allAssets: [PHAsset]) async -> [PHAsset] {
        guard
            let filter = selectedKeywordFilter,
            let cacheStore
        else {
            return allAssets
        }

        let matchingIdentifiers = await matchingAssetIdentifiers(
            forKeyword: filter,
            from: allAssets,
            cacheStore: cacheStore
        )
        return allAssets.filter { matchingIdentifiers.contains($0.localIdentifier) }
    }

    private func matchingAssetIdentifiers(
        forKeyword keyword: String,
        from assets: [PHAsset],
        cacheStore: PhotoCacheStoreProtocol
    ) async -> Set<String> {
        var identifiers = Set<String>()

        for asset in assets {
            let keywords = await cacheStore.fetchKeywords(for: asset.localIdentifier)
            if keywords.contains(where: { $0.keyword == keyword }) {
                identifiers.insert(asset.localIdentifier)
            }
        }

        return identifiers
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
            allAssets.removeAll { selectedAssets.contains($0.localIdentifier) }
            assets.removeAll { selectedAssets.contains($0.localIdentifier) }
            selectedAssets.removeAll()
            isSelectionMode = false
            await loadAllPhotos()
        } catch {
            deleteError = error.localizedDescription
        }
    }
}

// MARK: - Preview

#if DEBUG
/// AllPhotosView loads PHAssets via photoAssetService.
/// PreviewPhotoAssetService returns empty arrays, so previews show the empty/loading states.
#Preview("All Photos - Loading") {
    NavigationStack {
        VStack(spacing: Spacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
            Text("사진을 불러오는 중...")
                .font(Typography.body)
                .foregroundStyle(AppColor.textSecondary)
        }
        .navigationTitle("전체 사진")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview("All Photos - Empty") {
    NavigationStack {
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
        .navigationTitle("전체 사진")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview("All Photos - With Service") {
    NavigationStack {
        AllPhotosView()
    }
    .environment(\.photoAssetService, PreviewPhotoAssetService.shared)
}
#endif
