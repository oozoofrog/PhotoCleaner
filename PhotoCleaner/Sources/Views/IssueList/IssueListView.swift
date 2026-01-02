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
    @State private var cachedStats: [(key: String, value: Int)] = []

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
        .alert(
            "삭제 실패",
            isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )
        ) {
            Button("확인") {
                deleteError = nil
            }
        } message: {
            Text(deleteError ?? "")
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
            VStack(spacing: Spacing.sm) {
                // 헤더: 문제 유형 설명 + 통계
                issueInfoHeader

                // Row-justified 사진 그리드 (자연 비율 유지)
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
                            }
                        }
                        .photoAspectRatio(issue.aspectRatio)
                    }
                }
                .padding(.horizontal, Spacing.sm)
            }
            .padding(.top, Spacing.sm)
        }
        .onAppear {
            if issueType == .downloadFailed {
                cachedStats = computeResourceStatistics()
            }
        }
    }

    // MARK: - Issue Info Header

    private var issueInfoHeader: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // 문제 유형 아이콘 + 이름
            Label(issueType.displayName, systemImage: issueType.iconName)
                .font(Typography.headline)
                .foregroundStyle(issueType.color)

            // 사용자용 설명
            Text(issueType.userDescription)
                .font(Typography.subheadline)
                .foregroundStyle(AppColor.textSecondary)

            // 다운로드 실패 유형인 경우 상세 통계 표시
            if issueType == .downloadFailed {
                resourceStatisticsView
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(AppColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        .padding(.horizontal, Spacing.sm)
    }

    // MARK: - Resource Statistics (다운로드 실패 전용)

    private var resourceStatisticsView: some View {
        Group {
            if !cachedStats.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Divider()
                        .padding(.vertical, Spacing.xs)

                    Text("상세 분류")
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.textTertiary)

                    ForEach(cachedStats.prefix(5), id: \.key) { key, count in
                        HStack {
                            Text(key)
                                .font(Typography.caption)
                                .foregroundStyle(AppColor.textPrimary)
                            Spacer()
                            Text("\(count)장")
                                .font(Typography.caption)
                                .foregroundStyle(AppColor.textSecondary)
                        }
                    }
                }
            }
        }
    }

    /// 리소스 타입별 통계 계산
    private func computeResourceStatistics() -> [(key: String, value: Int)] {
        let grouped = Dictionary(grouping: issues) { issue in
            issue.metadata.errorMessage ?? "알 수 없음"
        }
        return grouped
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
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
        isDeleting = true  // 즉시 설정하여 race condition 방지

        Task {
            await performDeletion()
        }
    }

    private func performDeletion() async {
        deleteError = nil
        defer { isDeleting = false }  // 함수 종료 시 항상 리셋

        let identifiersToDelete = issues
            .filter { selectedIssues.contains($0.id) }
            .map(\.assetIdentifier)

        // PHAsset.fetchAssets는 동기 함수지만 thread-safe하므로 직접 호출 가능
        let assetsToDelete = PHAsset.fetchAssets(
            withLocalIdentifiers: identifiersToDelete,
            options: nil
        )

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assetsToDelete)
            }
            selectedIssues.removeAll()
            isSelectionMode = false
        } catch {
            deleteError = error.localizedDescription
        }
    }
}

// MARK: - Photo Thumbnail View

struct PhotoThumbnailView: View {
    let issue: PhotoIssue
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void

    @State private var thumbnail: UIImage?
    @State private var loadFailed = false

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                // 썸네일 (레이아웃이 크기 결정, 자연 비율 유지)
                thumbnailContent
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

    /// 썸네일 콘텐츠 (레이아웃에서 제공한 크기에 맞춤)
    @ViewBuilder
    private var thumbnailContent: some View {
        if let image = thumbnail {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if loadFailed {
            // 로딩 실패 시 플레이스홀더
            Rectangle()
                .fill(AppColor.backgroundSecondary)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(AppColor.textTertiary)
                }
        } else {
            // 로딩 중
            Rectangle()
                .fill(AppColor.backgroundSecondary)
                .overlay {
                    ProgressView()
                }
        }
    }

    /// 썸네일 로드 (자연 비율에 맞는 크기로 요청)
    /// - Note: deliveryMode = .highQualityFormat + isNetworkAccessAllowed = false 조합으로 단일 콜백 보장
    private func loadThumbnail() async {
        guard let asset = PHAsset.asset(withIdentifier: issue.assetIdentifier) else {
            loadFailed = true
            return
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat  // degraded 이미지 없이 최종 이미지만 전달
        options.isNetworkAccessAllowed = false     // 네트워크 로딩 없음 → 단일 콜백 보장
        options.resizeMode = .fast

        // 자연 비율에 맞는 썸네일 크기 계산
        let scale = UIScreen.main.scale
        let targetHeight = ThumbnailSize.gridHeight
        let targetWidth = targetHeight * issue.aspectRatio
        let size = CGSize(width: targetWidth * scale, height: targetHeight * scale)

        let result = await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }

        if let image = result {
            thumbnail = image
        } else {
            loadFailed = true
        }
    }
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
