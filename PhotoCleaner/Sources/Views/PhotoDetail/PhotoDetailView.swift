//
//  PhotoDetailView.swift
//  PhotoCleaner
//

import SwiftUI
import Photos

struct PhotoDetailView: View {
    let asset: PHAsset
    let issue: PhotoIssue?

    @State private var fullImage: UIImage?
    @State private var isLoading = true
    @State private var showDeleteConfirmation = false
    @State private var showMetadata = false
    @State private var deleteError: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.photoAssetService) private var photoAssetService

    init(asset: PHAsset, issue: PhotoIssue? = nil) {
        self.asset = asset
        self.issue = issue
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                if let image = fullImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                } else if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                } else {
                    VStack(spacing: Spacing.md) {
                        Image(systemName: "photo")
                            .font(.system(size: IconSize.hero))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("이미지를 불러올 수 없습니다")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }

                VStack {
                    Spacer()
                    bottomInfoBar
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showMetadata = true
                    } label: {
                        Label("정보 보기", systemImage: "info.circle")
                    }

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("삭제", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.white)
                }
            }
        }
        .confirmationDialog(
            "사진 삭제",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                deletePhoto()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("이 사진을 삭제할까요?\n삭제된 사진은 '최근 삭제된 항목'으로 이동됩니다.")
        }
        .sheet(isPresented: $showMetadata) {
            PhotoMetadataSheet(asset: asset, issue: issue)
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
        .task {
            await loadFullImage()
        }
    }

    // MARK: - Views

    private var bottomInfoBar: some View {
        ZStack(alignment: .bottom) {
            // Gradient overlay for better text readability
            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(0.3),
                    .black.opacity(0.5)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 120)
            .allowsHitTesting(false)

            VStack(spacing: Spacing.sm) {
                if let issue = issue {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: issue.issueType.iconName)
                            .foregroundStyle(AppColor.accent)
                            .font(.system(size: IconSize.sm, weight: .medium))

                        Text(issue.issueType.displayName)
                            .font(Typography.subheadline.weight(.medium))
                            .foregroundStyle(.white)

                        Spacer()
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(
                        Capsule()
                            .fill(AppColor.accent.opacity(0.15))
                            .overlay(
                                Capsule()
                                    .strokeBorder(AppColor.accent.opacity(0.3), lineWidth: 1)
                            )
                    )
                }

                HStack {
                    if let creationDate = asset.creationDate {
                        Text(creationDate.formatted(date: .abbreviated, time: .shortened))
                            .font(Typography.caption)
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    Spacer()

                    Text("\(asset.pixelWidth) × \(asset.pixelHeight)")
                        .font(Typography.caption)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
            .padding(Spacing.md)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Methods

    private func loadFullImage() async {
        let targetSize = CGSize(
            width: CGFloat(asset.pixelWidth),
            height: CGFloat(asset.pixelHeight)
        )

        do {
            let image = try await photoAssetService.requestUIImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                request: .fullQualityNetworkAllowed
            )
            fullImage = image
        } catch is CancellationError {
        } catch {
            fullImage = nil
        }
        isLoading = false
    }

    private func deletePhoto() {
        Task {
            do {
                try await photoAssetService.deleteAssets([asset])
                dismiss()
            } catch {
                deleteError = error.localizedDescription
            }
        }
    }
}

// MARK: - Metadata Sheet

struct PhotoMetadataSheet: View {
    let asset: PHAsset
    let issue: PhotoIssue?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let issue = issue {
                    Section("문제 정보") {
                        LabeledContent("유형", value: issue.issueType.displayName)
                        LabeledContent("심각도", value: issue.severity.displayName)

                        if let errorMessage = issue.metadata.errorMessage {
                            LabeledContent("상세", value: errorMessage)
                        }

                        if let fileSize = issue.metadata.fileSize {
                            LabeledContent("파일 크기", value: ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
                        }
                    }
                }

                Section("사진 정보") {
                    LabeledContent("해상도", value: "\(asset.pixelWidth) × \(asset.pixelHeight)")

                    if let creationDate = asset.creationDate {
                        LabeledContent("촬영일", value: creationDate.formatted(date: .long, time: .shortened))
                    }

                    if let modificationDate = asset.modificationDate {
                        LabeledContent("수정일", value: modificationDate.formatted(date: .long, time: .shortened))
                    }

                    LabeledContent("미디어 타입", value: mediaTypeString)

                    if asset.isFavorite {
                        LabeledContent("즐겨찾기", value: "예")
                    }
                }

                Section("위치") {
                    if let location = asset.location {
                        LabeledContent("위도", value: String(format: "%.6f", location.coordinate.latitude))
                        LabeledContent("경도", value: String(format: "%.6f", location.coordinate.longitude))
                    } else {
                        Text("위치 정보 없음")
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }
            }
            .navigationTitle("사진 정보")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var mediaTypeString: String {
        switch asset.mediaType {
        case .image: "사진"
        case .video: "비디오"
        case .audio: "오디오"
        default: "알 수 없음"
        }
    }
}

// MARK: - Preview

#if DEBUG
/// PhotoDetailView requires a real PHAsset which is not available in Preview.
/// These previews demonstrate the visual layout using static content.
#Preview("Photo Detail - With Image") {
    NavigationStack {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                // Simulated image
                Image(systemName: "photo.artframe")
                    .font(.system(size: 100))
                    .foregroundStyle(.white.opacity(0.3))

                VStack {
                    Spacer()
                    // Bottom info bar simulation
                    ZStack(alignment: .bottom) {
                        // Gradient overlay for better text readability
                        LinearGradient(
                            colors: [
                                .clear,
                                .black.opacity(0.3),
                                .black.opacity(0.5)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 120)
                        .allowsHitTesting(false)

                        VStack(spacing: Spacing.sm) {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "camera.viewfinder")
                                    .foregroundStyle(AppColor.accent)
                                    .font(.system(size: IconSize.sm, weight: .medium))

                                Text("스크린샷")
                                    .font(Typography.subheadline.weight(.medium))
                                    .foregroundStyle(.white)

                                Spacer()
                            }
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(
                                Capsule()
                                    .fill(AppColor.accent.opacity(0.15))
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(AppColor.accent.opacity(0.3), lineWidth: 1)
                                    )
                            )

                            HStack {
                                Text("2025년 1월 25일 오후 3:30")
                                    .font(Typography.caption)
                                    .foregroundStyle(.white.opacity(0.9))
                                Spacer()
                                Text("1170 × 2532")
                                    .font(Typography.caption)
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                        .padding(Spacing.md)
                        .background(.ultraThinMaterial)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.white)
            }
        }
    }
}

#Preview("Photo Detail - Loading") {
    NavigationStack {
        ZStack {
            Color.black.ignoresSafeArea()
            ProgressView()
                .tint(.white)
                .scaleEffect(1.5)
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Metadata Sheet") {
    NavigationStack {
        List {
            Section("문제 정보") {
                LabeledContent("유형", value: "스크린샷")
                LabeledContent("심각도", value: "낮음")
            }

            Section("사진 정보") {
                LabeledContent("해상도", value: "1170 × 2532")
                LabeledContent("촬영일", value: "2025년 1월 25일 오후 3:30")
                LabeledContent("미디어 타입", value: "사진")
            }

            Section("위치") {
                Text("위치 정보 없음")
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .navigationTitle("사진 정보")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
