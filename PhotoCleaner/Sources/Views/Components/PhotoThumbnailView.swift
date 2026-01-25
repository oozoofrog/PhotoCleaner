//
//  PhotoThumbnailView.swift
//  PhotoCleaner
//
//  사진 썸네일 뷰 컴포넌트
//

import SwiftUI
import Photos

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
