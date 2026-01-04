//
//  IssueListView.swift
//  PhotoCleaner
//
//  문제 사진 목록 화면
//

import SwiftUI
import Photos

enum DateFilter: String, CaseIterable, Identifiable {
    case all = "전체"
    case today = "오늘"
    case thisWeek = "이번 주"
    case thisMonth = "이번 달"
    case older = "오래된 것"

    var id: String { rawValue }
}

struct IssueListView: View {
    let issueType: IssueType
    let issues: [PhotoIssue]
    var duplicateGroups: [DuplicateGroup] = []
    @Binding var selectedSizeOption: LargeFileSizeOption
    var onLargeFileSizeChange: (@Sendable (LargeFileSizeOption) async -> Void)?

    @Environment(\.photoAssetService) private var photoAssetService
    @State private var selectedIssues: Set<String> = []
    @State private var isSelectionMode = false
    @State private var showDeleteConfirmation = false
    @State private var cachedStats: [(key: String, value: Int)] = []
    @State private var selectedDateFilter: DateFilter = .all
    @State private var groupedByDate: [DateFilter: [PhotoIssue]] = [:]
    @State private var sizeChangeTask: Task<Void, Never>?
    @State private var selectedIssue: PhotoIssue?
    @State private var groupToDelete: DuplicateGroup?

    /// 대용량 파일은 크기순 정렬, 그 외는 원본 순서
    private var sortedIssues: [PhotoIssue] {
        if issueType == .largeFile {
            return issues.sorted { ($0.metadata.fileSize ?? 0) > ($1.metadata.fileSize ?? 0) }
        }
        return issues
    }

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
            Button("확인") {
                deleteError = nil
            }
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

    // MARK: - Issue List Content

    private var issueListContent: some View {
        ScrollView {
            VStack(spacing: Spacing.sm) {
                issueInfoHeader

                if issueType == .screenshot {
                    screenshotDateFilterPicker
                    screenshotGroupedContent
                } else if issueType == .largeFile {
                    largeFileSizeFilterPicker
                    standardPhotoGrid(issues: sortedIssues)
                } else if issueType == .duplicate && !duplicateGroups.isEmpty {
                    duplicateGroupsContent
                } else {
                    standardPhotoGrid(issues: sortedIssues)
                }
            }
            .padding(.top, Spacing.sm)
        }
        .onAppear {
            if issueType == .downloadFailed {
                cachedStats = computeResourceStatistics()
            }
            if issueType == .screenshot {
                groupedByDate = groupIssuesByDate(issues)
            }
        }
        .onDisappear {
            sizeChangeTask?.cancel()
        }
    }

    private func standardPhotoGrid(issues: [PhotoIssue]) -> some View {
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
                        selectedIssue = issue
                    }
                }
                .photoAspectRatio(issue.aspectRatio)
            }
        }
        .padding(.horizontal, Spacing.sm)
    }

    private var screenshotDateFilterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(DateFilter.allCases) { filter in
                    let count = filter == .all ? issues.count : (groupedByDate[filter]?.count ?? 0)
                    Button {
                        withAnimation { selectedDateFilter = filter }
                    } label: {
                        Text("\(filter.rawValue) (\(count))")
                            .font(Typography.subheadline)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .background(selectedDateFilter == filter ? AppColor.primary : AppColor.backgroundSecondary)
                            .foregroundStyle(selectedDateFilter == filter ? .white : AppColor.textPrimary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.sm)
        }
    }

    private var largeFileSizeFilterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(LargeFileSizeOption.allCases) { option in
                    Button {
                        guard option != selectedSizeOption else { return }
                        sizeChangeTask?.cancel()
                        sizeChangeTask = Task {
                            await onLargeFileSizeChange?(option)
                        }
                    } label: {
                        Text("\(option.displayName) 이상")
                            .font(Typography.subheadline)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .background(selectedSizeOption == option ? AppColor.primary : AppColor.backgroundSecondary)
                            .foregroundStyle(selectedSizeOption == option ? .white : AppColor.textPrimary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.sm)
        }
    }

    @ViewBuilder
    private var screenshotGroupedContent: some View {
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
            standardPhotoGrid(issues: filteredIssues)
        }
    }

    @ViewBuilder
    private var duplicateGroupsContent: some View {
        let sortedGroups = duplicateGroups.sorted { $0.potentialSavings > $1.potentialSavings }
        
        VStack(spacing: Spacing.md) {
            ForEach(sortedGroups) { group in
                DuplicateGroupSectionView(
                    group: group,
                    selectedIds: selectedIssues,
                    isSelectionMode: isSelectionMode
                ) { assetId in
                    if isSelectionMode {
                        toggleAssetSelection(assetId)
                    } else {
                        navigateToAsset(assetId)
                    }
                } onDeleteDuplicates: {
                    groupToDelete = group
                    showDeleteConfirmation = true
                }
            }
        }
        .padding(.horizontal, Spacing.sm)
    }
    
    private func toggleAssetSelection(_ assetId: String) {
        if let issue = issues.first(where: { $0.assetIdentifier == assetId }) {
            toggleSelection(issue.id)
        }
    }
    
    private func navigateToAsset(_ assetId: String) {
        if let issue = issues.first(where: { $0.assetIdentifier == assetId }) {
            selectedIssue = issue
        }
    }
    
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
    
    private var deleteConfirmationTitle: String {
        if groupToDelete != nil {
            return "중복 사진 삭제"
        }
        return "선택한 사진 삭제"
    }
    
    private var deleteConfirmationMessage: String {
        if let group = groupToDelete {
            let count = group.duplicateAssetIdentifiers.count
            return "\(count)장의 중복 사진을 삭제할까요?\n원본은 유지됩니다."
        }
        return "\(selectedIssues.count)장의 사진을 삭제할까요?\n삭제된 사진은 '최근 삭제된 항목'으로 이동됩니다."
    }

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
    
    private func deleteDuplicatesInGroup() {
        guard let group = groupToDelete, !isDeleting else { return }
        isDeleting = true
        
        Task {
            await performGroupDeletion(group: group)
            groupToDelete = nil
        }
    }
    
    private func performGroupDeletion(group: DuplicateGroup) async {
        deleteError = nil
        defer { isDeleting = false }
        
        let identifiersToDelete = group.duplicateAssetIdentifiers
        
        do {
            try await photoAssetService.deleteAssets(withIdentifiers: identifiersToDelete)
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

    @Environment(\.displayScale) private var displayScale
    @Environment(\.photoAssetService) private var photoAssetService
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

    private func loadThumbnail() async {
        guard let asset = photoAssetService.asset(withIdentifier: issue.assetIdentifier) else {
            loadFailed = true
            return
        }

        do {
            let image = try await photoAssetService.requestGridThumbnailUIImage(
                for: asset,
                targetHeight: ThumbnailSize.gridHeight,
                aspectRatio: issue.aspectRatio,
                scale: displayScale
            )
            thumbnail = image
        } catch {
            loadFailed = true
        }
    }
}

// MARK: - Preview

#Preview("Issue List") {
    NavigationStack {
        IssueListView(
            issueType: .screenshot,
            issues: [],
            selectedSizeOption: .constant(.mb10)
        )
    }
}
