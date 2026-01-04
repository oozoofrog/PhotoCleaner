//
//  PhotoAssetService.swift
//  PhotoCleaner
//

import Photos
import SwiftUI
import UIKit

struct PhotoImageRequest: Sendable {
    var deliveryMode: PHImageRequestOptionsDeliveryMode
    var resizeMode: PHImageRequestOptionsResizeMode
    var networkAccessAllowed: Bool

    static let gridThumbnail = PhotoImageRequest(
        deliveryMode: .highQualityFormat,
        resizeMode: .fast,
        networkAccessAllowed: false
    )

    static let fullQualityNetworkAllowed = PhotoImageRequest(
        deliveryMode: .highQualityFormat,
        resizeMode: .none,
        networkAccessAllowed: true
    )

    static let visionThumbnail = PhotoImageRequest(
        deliveryMode: .fastFormat,
        resizeMode: .fast,
        networkAccessAllowed: false
    )
}

enum PhotoAssetServiceError: Error, LocalizedError, Sendable {
    case imageNotAvailable
    case cgImageNotAvailable
    case assetNotFound(String)

    var errorDescription: String? {
        switch self {
        case .imageNotAvailable: "이미지를 불러올 수 없습니다."
        case .cgImageNotAvailable: "CGImage 변환에 실패했습니다."
        case .assetNotFound(let id): "에셋을 찾을 수 없습니다: \(id)"
        }
    }
}

protocol PhotoAssetService: Sendable {
    func asset(withIdentifier identifier: String) -> PHAsset?
    func fetchAssets(withIdentifiers identifiers: [String]) -> [PHAsset]
    func fetchAllPhotoAssets(sortedBy sortDescriptors: [NSSortDescriptor]) -> [PHAsset]

    func requestUIImage(
        for asset: PHAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode,
        request: PhotoImageRequest
    ) async throws -> UIImage

    func requestGridThumbnailUIImage(
        for asset: PHAsset,
        targetHeight: CGFloat,
        aspectRatio: CGFloat,
        scale: CGFloat
    ) async throws -> UIImage

    func requestThumbnailCGImageForVision(
        for asset: PHAsset,
        pointSize: CGSize,
        scale: CGFloat
    ) async throws -> (cgImage: CGImage, estimatedByteCount: Int64)

    func deleteAssets(_ assets: [PHAsset]) async throws
    func deleteAssets(withIdentifiers identifiers: [String]) async throws
}

/// PHImageManager와 PHPhotoLibrary는 Objective-C thread-safe 클래스이므로
/// @unchecked Sendable 사용이 안전합니다.
/// - imageManager: let으로 선언되어 초기화 후 변경 불가
/// - photoLibrary: let으로 선언되어 초기화 후 변경 불가
final class SystemPhotoAssetService: PhotoAssetService, @unchecked Sendable {

    private let imageManager: PHImageManager
    private let photoLibrary: PHPhotoLibrary

    init(
        imageManager: PHImageManager = PHCachingImageManager(),
        photoLibrary: PHPhotoLibrary = .shared()
    ) {
        self.imageManager = imageManager
        self.photoLibrary = photoLibrary
    }

    func asset(withIdentifier identifier: String) -> PHAsset? {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        return result.firstObject
    }

    func fetchAssets(withIdentifiers identifiers: [String]) -> [PHAsset] {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }

    func fetchAllPhotoAssets(sortedBy sortDescriptors: [NSSortDescriptor]) -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = sortDescriptors
        let result = PHAsset.fetchAssets(with: .image, options: options)

        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }

    func requestGridThumbnailUIImage(
        for asset: PHAsset,
        targetHeight: CGFloat,
        aspectRatio: CGFloat,
        scale: CGFloat
    ) async throws -> UIImage {
        let targetWidth = targetHeight * aspectRatio
        let pixelSize = CGSize(width: targetWidth * scale, height: targetHeight * scale)

        return try await requestUIImage(
            for: asset,
            targetSize: pixelSize,
            contentMode: .aspectFill,
            request: .gridThumbnail
        )
    }

    func requestThumbnailCGImageForVision(
        for asset: PHAsset,
        pointSize: CGSize,
        scale: CGFloat
    ) async throws -> (cgImage: CGImage, estimatedByteCount: Int64) {
        let pixelSize = CGSize(width: pointSize.width * scale, height: pointSize.height * scale)

        let image = try await requestUIImage(
            for: asset,
            targetSize: pixelSize,
            contentMode: .aspectFill,
            request: .visionThumbnail
        )

        if let cgImage = image.cgImage {
            let estimated = Int64(asset.pixelWidth * asset.pixelHeight) / 4
            return (cgImage, estimated)
        }

        let renderer = UIGraphicsImageRenderer(size: image.size)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        guard let cgImage = rendered.cgImage else {
            throw PhotoAssetServiceError.cgImageNotAvailable
        }

        let estimated = Int64(asset.pixelWidth * asset.pixelHeight) / 4
        return (cgImage, estimated)
    }

    func requestUIImage(
        for asset: PHAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode,
        request: PhotoImageRequest
    ) async throws -> UIImage {
        let requestIdBox = RequestIdBox(imageManager: imageManager)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let options = PHImageRequestOptions()
                options.isSynchronous = false
                options.deliveryMode = request.deliveryMode
                options.resizeMode = request.resizeMode
                options.isNetworkAccessAllowed = request.networkAccessAllowed

                let hasResumed = HasResumedBox()

                let requestId = self.imageManager.requestImage(
                    for: asset,
                    targetSize: targetSize,
                    contentMode: contentMode,
                    options: options
                ) { image, info in
                    if let error = info?[PHImageErrorKey] as? Error {
                        hasResumed.resumeOnce { continuation.resume(throwing: error) }
                        return
                    }

                    if (info?[PHImageCancelledKey] as? Bool) == true {
                        hasResumed.resumeOnce { continuation.resume(throwing: CancellationError()) }
                        return
                    }

                    if (info?[PHImageResultIsDegradedKey] as? Bool) == true {
                        return
                    }

                    guard let image else {
                        hasResumed.resumeOnce { continuation.resume(throwing: PhotoAssetServiceError.imageNotAvailable) }
                        return
                    }

                    hasResumed.resumeOnce { continuation.resume(returning: image) }
                }

                requestIdBox.setRequestId(requestId)
            }
        } onCancel: {
            requestIdBox.cancelIfNeeded()
        }
    }

    func deleteAssets(_ assets: [PHAsset]) async throws {
        guard !assets.isEmpty else { return }
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: assets.map(\.localIdentifier), options: nil)

        try await photoLibrary.performChanges {
            PHAssetChangeRequest.deleteAssets(fetchResult)
        }
    }

    func deleteAssets(withIdentifiers identifiers: [String]) async throws {
        guard !identifiers.isEmpty else { return }
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)

        try await photoLibrary.performChanges {
            PHAssetChangeRequest.deleteAssets(fetchResult)
        }
    }
}

/// NSLock으로 동기화된 PHImageRequestID 박스.
/// 취소 요청과 요청 ID 설정 간의 경쟁 상태를 안전하게 처리합니다.
final class RequestIdBox: @unchecked Sendable {
    private let lock = NSLock()
    private let imageManager: PHImageManager
    private nonisolated(unsafe) var requestId: PHImageRequestID?
    private nonisolated(unsafe) var isCancelled = false
    
    init(imageManager: PHImageManager = PHImageManager.default()) {
        self.imageManager = imageManager
    }

    nonisolated func setRequestId(_ id: PHImageRequestID) {
        lock.lock()
        let shouldCancel = isCancelled
        if !shouldCancel {
            requestId = id
        }
        lock.unlock()
        
        if shouldCancel {
            imageManager.cancelImageRequest(id)
        }
    }

    nonisolated func cancelIfNeeded() {
        lock.lock()
        isCancelled = true
        let id = requestId
        requestId = nil
        lock.unlock()
        
        if let id {
            imageManager.cancelImageRequest(id)
        }
    }
}

/// NSLock으로 보호되는 단일 실행 보장 박스.
/// continuation이 한 번만 resume되도록 보장합니다.
final class HasResumedBox: @unchecked Sendable {
    private let lock = NSLock()
    private nonisolated(unsafe) var hasResumed = false

    nonisolated func resumeOnce(_ block: () -> Void) {
        lock.lock()
        let shouldResume = !hasResumed
        if shouldResume { hasResumed = true }
        lock.unlock()
        
        guard shouldResume else { return }
        block()
    }
}

private struct PhotoAssetServiceKey: EnvironmentKey {
    static let defaultValue: any PhotoAssetService = SystemPhotoAssetService()
}

extension EnvironmentValues {
    var photoAssetService: any PhotoAssetService {
        get { self[PhotoAssetServiceKey.self] }
        set { self[PhotoAssetServiceKey.self] = newValue }
    }
}
