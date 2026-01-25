#if DEBUG
import Photos
import UIKit

/// Preview implementation of PhotoAssetService for SwiftUI previews
/// Provides placeholder images and no-op implementations for all protocol methods
@MainActor
final class PreviewPhotoAssetService: PhotoAssetService {
    static let shared = PreviewPhotoAssetService()

    private init() {}

    // MARK: - Asset Fetching

    func asset(withIdentifier identifier: String) -> PHAsset? {
        return nil
    }

    func fetchAssets(withIdentifiers identifiers: [String]) -> [PHAsset] {
        return []
    }

    func fetchAllPhotoAssets(sortedBy sortDescriptors: [NSSortDescriptor]) -> [PHAsset] {
        return []
    }

    // MARK: - Image Requests

    func requestUIImage(
        for asset: PHAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode,
        request: PhotoImageRequest
    ) async throws -> UIImage {
        return createPlaceholderImage(size: targetSize, color: .systemBlue)
    }

    func requestGridThumbnailUIImage(
        for asset: PHAsset,
        targetHeight: CGFloat,
        aspectRatio: CGFloat,
        scale: CGFloat
    ) async throws -> UIImage {
        let width = targetHeight * aspectRatio
        let size = CGSize(width: width, height: targetHeight)
        return createPlaceholderImage(size: size, color: .systemGray)
    }

    func requestThumbnailCGImageForVision(
        for asset: PHAsset,
        pointSize: CGSize,
        scale: CGFloat
    ) async throws -> (cgImage: CGImage, estimatedByteCount: Int64) {
        let pixelSize = CGSize(width: pointSize.width * scale, height: pointSize.height * scale)
        let image = createPlaceholderImage(size: pixelSize, color: .systemGreen)

        guard let cgImage = image.cgImage else {
            throw NSError(
                domain: "PreviewPhotoAssetService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to create CGImage"]
            )
        }

        let bytesPerPixel = 4
        let estimatedByteCount = Int64(pixelSize.width * pixelSize.height) * Int64(bytesPerPixel)

        return (cgImage: cgImage, estimatedByteCount: estimatedByteCount)
    }

    // MARK: - Asset Deletion

    func deleteAssets(_ assets: [PHAsset]) async throws {
        // No-op for previews
    }

    func deleteAssets(withIdentifiers identifiers: [String]) async throws {
        // No-op for previews
    }

    // MARK: - Helper Methods

    /// Creates a placeholder UIImage with the specified size and color
    private func createPlaceholderImage(size: CGSize, color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))

            // Add a diagonal cross pattern to make it obvious this is a placeholder
            UIColor.white.withAlphaComponent(0.3).setStroke()
            context.cgContext.setLineWidth(2)

            context.cgContext.move(to: CGPoint(x: 0, y: 0))
            context.cgContext.addLine(to: CGPoint(x: size.width, y: size.height))
            context.cgContext.strokePath()

            context.cgContext.move(to: CGPoint(x: size.width, y: 0))
            context.cgContext.addLine(to: CGPoint(x: 0, y: size.height))
            context.cgContext.strokePath()
        }
    }
}
#endif
