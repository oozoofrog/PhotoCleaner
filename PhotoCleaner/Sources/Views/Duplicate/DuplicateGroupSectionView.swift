//
//  DuplicateGroupSectionView.swift
//  PhotoCleaner
//

import SwiftUI
import Photos

struct DuplicateGroupSectionView: View {
    let group: DuplicateGroup
    let selectedIds: Set<String>
    let isSelectionMode: Bool
    let onPhotoTap: (String) -> Void
    let onDeleteDuplicates: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            groupHeader
            photoGrid
            if !isSelectionMode {
                deleteButton
            }
        }
        .padding(Spacing.md)
        .background(AppColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
    }
    
    private var groupHeader: some View {
        HStack {
            Label(group.similarityLabel, systemImage: group.isExactDuplicate ? "equal.square" : "square.on.square")
                .font(Typography.subheadline)
                .foregroundStyle(group.isExactDuplicate ? AppColor.primary : AppColor.secondary)
            
            Spacer()
            
            Text("\(group.count)장 · \(group.formattedSavings) 정리 가능")
                .font(Typography.caption)
                .foregroundStyle(AppColor.textSecondary)
        }
    }
    
    private var photoGrid: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(group.assetIdentifiers, id: \.self) { assetId in
                    DuplicatePhotoCell(
                        assetId: assetId,
                        isOriginal: group.isOriginal(assetId),
                        isSelected: selectedIds.contains(assetId),
                        isSelectionMode: isSelectionMode
                    ) {
                        onPhotoTap(assetId)
                    }
                }
            }
        }
    }
    
    private var deleteButton: some View {
        Button {
            onDeleteDuplicates()
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("원본 제외 모두 삭제")
            }
            .font(Typography.subheadline)
            .foregroundStyle(AppColor.destructive)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
        }
        .buttonStyle(.plain)
    }
}

struct DuplicatePhotoCell: View {
    let assetId: String
    let isOriginal: Bool
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void
    
    @Environment(\.displayScale) private var displayScale
    @Environment(\.photoAssetService) private var photoAssetService
    @State private var thumbnail: UIImage?
    @State private var loadFailed = false
    
    private let cellSize: CGFloat = 80
    
    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topLeading) {
                thumbnailImage
                    .frame(width: cellSize, height: cellSize)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                
                if isOriginal {
                    originalBadge
                }
                
                if isSelectionMode {
                    selectionIndicator
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
    private var thumbnailImage: some View {
        if let image = thumbnail {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if loadFailed {
            Rectangle()
                .fill(AppColor.backgroundTertiary)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(AppColor.textTertiary)
                }
        } else {
            Rectangle()
                .fill(AppColor.backgroundTertiary)
                .overlay {
                    ProgressView()
                }
        }
    }
    
    private var originalBadge: some View {
        Text("원본")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(AppColor.success)
            .clipShape(Capsule())
            .padding(4)
    }
    
    private var selectionIndicator: some View {
        VStack {
            HStack {
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: IconSize.md))
                    .foregroundStyle(isSelected ? AppColor.primary : .white)
                    .background(
                        Circle()
                            .fill(isSelected ? .white : .black.opacity(0.3))
                            .frame(width: IconSize.md, height: IconSize.md)
                    )
                    .padding(4)
            }
            Spacer()
        }
    }
    
    private func loadThumbnail() async {
        guard let asset = photoAssetService.asset(withIdentifier: assetId) else {
            loadFailed = true
            return
        }

        do {
            let image = try await photoAssetService.requestGridThumbnailUIImage(
                for: asset,
                targetHeight: cellSize,
                aspectRatio: 1.0,
                scale: displayScale
            )
            thumbnail = image
        } catch is CancellationError {
        } catch {
            loadFailed = true
        }
    }
}

#if DEBUG
#Preview("DuplicateGroup - Normal") {
    DuplicateGroupSectionView(
        group: PreviewSampleData.duplicateGroups.first!,
        selectedIds: [],
        isSelectionMode: false,
        onPhotoTap: { _ in },
        onDeleteDuplicates: {}
    )
    .environment(\.photoAssetService, PreviewPhotoAssetService.shared)
    .padding()
}

#Preview("DuplicateGroup - Selection Mode") {
    DuplicateGroupSectionView(
        group: PreviewSampleData.duplicateGroups.first!,
        selectedIds: Set(PreviewSampleData.duplicateGroups.first!.assetIdentifiers.prefix(2)),
        isSelectionMode: true,
        onPhotoTap: { _ in },
        onDeleteDuplicates: {}
    )
    .environment(\.photoAssetService, PreviewPhotoAssetService.shared)
    .padding()
}

#Preview("DuplicatePhotoCell") {
    let group = PreviewSampleData.duplicateGroups.first!
    let assetId = group.assetIdentifiers.first!

    HStack(spacing: Spacing.md) {
        DuplicatePhotoCell(
            assetId: assetId,
            isOriginal: true,
            isSelected: false,
            isSelectionMode: false,
            onTap: {}
        )

        DuplicatePhotoCell(
            assetId: assetId,
            isOriginal: false,
            isSelected: true,
            isSelectionMode: true,
            onTap: {}
        )
    }
    .environment(\.photoAssetService, PreviewPhotoAssetService.shared)
    .padding()
}
#endif
