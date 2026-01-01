//
//  IssueListView.swift
//  PhotoCleaner
//
//  문제 사진 목록 화면
//

import SwiftUI
import Photos

struct IssueListView: View {
    let issueType: IssueType
    let issues: [PhotoIssue]

    @State private var selectedIssues: Set<String> = []
    @State private var isSelectionMode = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        Group {
            if issues.isEmpty {
                emptyStateView
            } else {
                issueListContent
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

    // MARK: - Issue List Content

    private var issueListContent: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(minimum: GridLayout.minItemWidth, maximum: GridLayout.maxItemWidth),
                        spacing: Spacing.xs
                    )
                ],
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
                        }
                    }
                }
            }
            .padding(Spacing.sm)
        }
    }

    // MARK: - Selection Toolbar

    private var selectionToolbar: some View {
        HStack {
            Button {
                if selectedIssues.count == issues.count {
                    selectedIssues.removeAll()
                } else {
                    selectedIssues = Set(issues.map(\.id))
                }
            } label: {
                Text(selectedIssues.count == issues.count ? "전체 해제" : "전체 선택")
            }

            Spacer()

            Text("\(selectedIssues.count)장 선택됨")
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

    @State private var isDeleting = false
    @State private var deleteError: String?

    // MARK: - Actions

    private func toggleSelection(_ id: String) {
        if selectedIssues.contains(id) {
            selectedIssues.remove(id)
        } else {
            selectedIssues.insert(id)
        }
    }

    /// 선택된 사진 삭제 (비동기, 백그라운드 처리)
    private func deleteSelectedPhotos() {
        guard !isDeleting else { return }

        Task {
            await performDeletion()
        }
    }

    private func performDeletion() async {
        isDeleting = true
        deleteError = nil

        let identifiersToDelete = issues
            .filter { selectedIssues.contains($0.id) }
            .map(\.assetIdentifier)

        // 백그라운드에서 fetch 수행
        let assetsToDelete = await Task.detached {
            PHAsset.fetchAssets(
                withLocalIdentifiers: identifiersToDelete,
                options: nil
            )
        }.value

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assetsToDelete)
            }
            selectedIssues.removeAll()
            isSelectionMode = false
        } catch {
            deleteError = error.localizedDescription
        }

        isDeleting = false
    }
}

// MARK: - Photo Thumbnail View

struct PhotoThumbnailView: View {
    let issue: PhotoIssue
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                // 썸네일
                Group {
                    if let image = thumbnail {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(AppColor.backgroundSecondary)
                            .aspectRatio(1, contentMode: .fill)
                            .overlay {
                                ProgressView()
                            }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))

                // 문제 유형 배지
                if !isSelectionMode {
                    Image(systemName: issue.issueType.iconName)
                        .font(.system(size: IconSize.sm))
                        .foregroundStyle(.white)
                        .padding(Spacing.xs)
                        .background(issue.issueType.color)
                        .clipShape(Circle())
                        .padding(Spacing.xs)
                }

                // 선택 체크박스
                if isSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: IconSize.md))
                        .foregroundStyle(isSelected ? AppColor.primary : .white)
                        .background(
                            Circle()
                                .fill(isSelected ? .white : .black.opacity(0.3))
                                .frame(width: IconSize.md, height: IconSize.md)
                        )
                        .padding(Spacing.xs)
                }
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: CornerRadius.sm)
                        .stroke(AppColor.primary, lineWidth: 3)
                }
            }
        }
        .buttonStyle(.plain)
        .task {
            await loadThumbnail()
        }
    }

    /// 썸네일 로드 (안전한 continuation 사용)
    private func loadThumbnail() async {
        guard let asset = PHAsset.asset(withIdentifier: issue.assetIdentifier) else { return }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat  // 단일 콜백 보장
        options.isNetworkAccessAllowed = false
        options.resizeMode = .fast
        options.isSynchronous = false

        let size = ThumbnailSize.grid

        // 안전한 continuation 패턴 사용
        let loadedImage: UIImage? = await withCheckedContinuation { continuation in
            var hasResumed = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                // 이미 resume된 경우 무시
                guard !hasResumed else { return }

                // degraded 이미지가 아닌 경우에만 resume
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                let hasError = info?[PHImageErrorKey] != nil

                // 최종 이미지이거나 에러/취소된 경우 resume
                if !isDegraded || isCancelled || hasError {
                    hasResumed = true
                    continuation.resume(returning: image)
                }
            }
        }

        thumbnail = loadedImage
    }
}

// MARK: - Thumbnail Size Constants

enum ThumbnailSize {
    static let grid = CGSize(width: 200, height: 200)
}

// MARK: - Grid Layout Constants

enum GridLayout {
    /// 그리드 아이템 최소 너비
    static let minItemWidth: CGFloat = 100
    /// 그리드 아이템 최대 너비
    static let maxItemWidth: CGFloat = 150
}

// MARK: - Preview

#Preview("Issue List") {
    NavigationStack {
        IssueListView(
            issueType: .screenshot,
            issues: []
        )
    }
}
