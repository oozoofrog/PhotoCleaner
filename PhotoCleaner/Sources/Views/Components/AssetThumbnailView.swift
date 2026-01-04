//
//  AssetThumbnailView.swift
//  PhotoCleaner
//

import SwiftUI
import Photos

struct AssetThumbnailView: View {
    let asset: PHAsset
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void

    @Environment(\.displayScale) private var displayScale
    @Environment(\.photoAssetService) private var photoAssetService
    @State private var thumbnail: UIImage?
    @State private var loadFailed = false

    var aspectRatio: CGFloat {
        guard asset.pixelHeight > 0 else { return 1.0 }
        return CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                thumbnailContent
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))

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

    @ViewBuilder
    private var thumbnailContent: some View {
        if let image = thumbnail {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if loadFailed {
            Rectangle()
                .fill(AppColor.backgroundSecondary)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(AppColor.textTertiary)
                }
        } else {
            Rectangle()
                .fill(AppColor.backgroundSecondary)
                .overlay {
                    ProgressView()
                }
        }
    }

    private func loadThumbnail() async {
        do {
            let image = try await photoAssetService.requestGridThumbnailUIImage(
                for: asset,
                targetHeight: ThumbnailSize.gridHeight,
                aspectRatio: aspectRatio,
                scale: displayScale
            )
            thumbnail = image
        } catch is CancellationError {
        } catch {
            loadFailed = true
        }
    }
}

// MARK: - Preview

#Preview("Asset Thumbnail") {
    AssetThumbnailView(
        asset: PHAsset(),
        isSelected: false,
        isSelectionMode: false,
        onTap: {}
    )
    .frame(width: 100, height: 100)
}
