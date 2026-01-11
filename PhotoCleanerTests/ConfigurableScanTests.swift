//
//  ConfigurableScanTests.swift
//  PhotoCleanerTests
//
//  Created by oozoofrog on 1/11/26.
//

import Testing
import Photos
import UIKit
@testable import PhotoCleaner

@Suite("Configurable Scan Tests")
struct ConfigurableScanTests {

    @Test("ScanService accepts configuration parameters")
    func scanServiceAcceptsConfig() async throws {
        // Given
        let service = PhotoScanService(photoAssetService: MockPhotoAssetService())
        
        // When & Then (Should not throw)
        _ = try await service.scanAll(
            duplicateDetectionMode: .exactOnly, 
            similarityThreshold: .percent95
        ) { _ in }
        
        _ = try await service.scanAll(
            duplicateDetectionMode: .includeSimilar, 
            similarityThreshold: .percent80
        ) { _ in }
    }
}

// Mock Helper
class MockPhotoAssetService: PhotoAssetService, @unchecked Sendable {
    func asset(withIdentifier identifier: String) -> PHAsset? { nil }
    
    func fetchAssets(withIdentifiers identifiers: [String]) -> [PHAsset] { [] }
    
    func fetchAllPhotoAssets(sortedBy sortDescriptors: [NSSortDescriptor]) -> [PHAsset] { [] }
    
    func deleteAssets(_ assets: [PHAsset]) async throws { }
    
    func deleteAssets(withIdentifiers identifiers: [String]) async throws { }
    
    func requestUIImage(for asset: PHAsset, targetSize: CGSize, contentMode: PHImageContentMode, request: PhotoImageRequest) async throws -> UIImage {
        // Return a dummy placeholder
        return UIImage()
    }
    
    func requestThumbnailCGImageForVision(for asset: PHAsset, pointSize: CGSize, scale: CGFloat) async throws -> (cgImage: CGImage, estimatedByteCount: Int64) {
        // Return a dummy CGImage
        let width = Int(pointSize.width * scale)
        let height = Int(pointSize.height * scale)
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        let image = context.makeImage()!
        return (image, 1024)
    }
    
    func requestGridThumbnailUIImage(for asset: PHAsset, targetHeight: CGFloat, aspectRatio: CGFloat, scale: CGFloat) async throws -> UIImage {
        return UIImage() 
    }
}
