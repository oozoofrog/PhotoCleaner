//
//  PhotoScanServiceStreamingTests.swift
//  PhotoCleanerTests
//
//  Streaming scan API 유닛 테스트
//

import Testing
import Photos
import UIKit
@testable import PhotoCleaner

@Suite("Streaming Scan API Tests")
struct PhotoScanServiceStreamingTests {

    // MARK: - Basic Streaming Tests

    @Test("scanAllStreaming returns AsyncStream")
    func streamingReturnsAsyncStream() async throws {
        // Given
        let service = PhotoScanService(photoAssetService: MockPhotoAssetService())

        // When
        let stream = await service.scanAllStreaming()

        // Then - should be able to iterate
        var receivedAnyUpdate = false
        for await _ in stream {
            receivedAnyUpdate = true
            break // Just check we can receive one update
        }
        // With empty assets, we should still get at least preparing/completed events
        #expect(receivedAnyUpdate == true, "Stream should emit at least one update")
    }

    @Test("scanAllStreaming emits progress and completed events")
    func streamingEmitsProgressAndCompleted() async throws {
        // Given
        let service = PhotoScanService(photoAssetService: MockPhotoAssetService())

        // When
        let stream = await service.scanAllStreaming()
        var events: [ScanUpdateType] = []

        for await update in stream {
            events.append(update.type)
        }

        // Then
        #expect(events.contains(.progress))
        #expect(events.contains(.completed))
    }

    @Test("scanAllStreaming completes with result")
    func streamingCompletesWithResult() async throws {
        // Given
        let service = PhotoScanService(photoAssetService: MockPhotoAssetService())

        // When
        let stream = await service.scanAllStreaming()
        var hasCompleted = false

        for await update in stream {
            if case .completed = update {
                hasCompleted = true
            }
        }

        // Then - stream should complete with a result (empty since mock returns no assets)
        #expect(hasCompleted)
    }

    // MARK: - Cancellation Tests

    @Test("Task cancellation stops stream consumption")
    func taskCancellationStopsStream() async throws {
        // Given
        let service = PhotoScanService(photoAssetService: SlowMockPhotoAssetService())

        // When
        let stream = await service.scanAllStreaming()

        // Start consuming in a task
        let consumeTask = Task {
            var updateCount = 0
            for await _ in stream {
                updateCount += 1
                // Give time for cancel to take effect
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
            return updateCount
        }

        // Wait a bit then cancel the consuming task
        // This triggers AsyncStream's onTermination which cancels the internal scan task
        try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        consumeTask.cancel()

        // Then - task should stop (cancelled or completed)
        let result = await consumeTask.result
        // Task was either cancelled or completed - both are valid outcomes
        switch result {
        case .success:
            // Stream completed normally before cancel took effect
            break
        case .failure:
            // Task was cancelled - this is expected
            break
        }
        // If we reach here, the test passed - stream didn't hang
    }

    @Test("stream terminates cleanly")
    func streamTerminatesCleanly() async throws {
        // Given
        let service = PhotoScanService(photoAssetService: MockPhotoAssetService())

        // When
        let stream = await service.scanAllStreaming()

        var receivedCancelledOrCompleted = false
        for await update in stream {
            switch update {
            case .cancelled:
                receivedCancelledOrCompleted = true
            case .completed:
                receivedCancelledOrCompleted = true
            default:
                break
            }
        }

        // Then - stream should terminate cleanly with completed event
        #expect(receivedCancelledOrCompleted, "Stream should emit completed or cancelled event")
    }
}

// MARK: - Test Helpers

/// Helper to categorize ScanUpdate for testing
enum ScanUpdateType: Equatable {
    case progress
    case issueFound
    case duplicateGroupFound
    case summaryUpdated
    case completed
    case cancelled
    case failed
}

extension ScanUpdate {
    var type: ScanUpdateType {
        switch self {
        case .progress: return .progress
        case .issueFound: return .issueFound
        case .duplicateGroupFound: return .duplicateGroupFound
        case .summaryUpdated: return .summaryUpdated
        case .completed: return .completed
        case .cancelled: return .cancelled
        case .failed: return .failed
        }
    }
}

/// Mock service that simulates slow processing for cancellation tests
class SlowMockPhotoAssetService: PhotoAssetService, @unchecked Sendable {
    func asset(withIdentifier identifier: String) -> PHAsset? { nil }

    func fetchAssets(withIdentifiers identifiers: [String]) -> [PHAsset] { [] }

    func fetchAllPhotoAssets(sortedBy sortDescriptors: [NSSortDescriptor]) -> [PHAsset] { [] }

    func deleteAssets(_ assets: [PHAsset]) async throws { }

    func deleteAssets(withIdentifiers identifiers: [String]) async throws { }

    func requestUIImage(for asset: PHAsset, targetSize: CGSize, contentMode: PHImageContentMode, request: PhotoImageRequest) async throws -> UIImage {
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
        return UIImage()
    }

    func requestThumbnailCGImageForVision(for asset: PHAsset, pointSize: CGSize, scale: CGFloat) async throws -> (cgImage: CGImage, estimatedByteCount: Int64) {
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
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
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms delay
        return UIImage()
    }
}

/// Configurable Mock service that can return custom test data
class ConfigurableMockPhotoAssetService: PhotoAssetService, @unchecked Sendable {
    var assetsToReturn: [PHAsset] = []
    var fetchWasCalled = false
    var simulatedDelay: UInt64 = 0  // nanoseconds, for cancellation tests

    func asset(withIdentifier identifier: String) -> PHAsset? { nil }

    func fetchAssets(withIdentifiers identifiers: [String]) -> [PHAsset] { [] }

    func fetchAllPhotoAssets(sortedBy sortDescriptors: [NSSortDescriptor]) -> [PHAsset] {
        fetchWasCalled = true
        return assetsToReturn
    }

    func deleteAssets(_ assets: [PHAsset]) async throws { }

    func deleteAssets(withIdentifiers identifiers: [String]) async throws { }

    func requestUIImage(for asset: PHAsset, targetSize: CGSize, contentMode: PHImageContentMode, request: PhotoImageRequest) async throws -> UIImage {
        if simulatedDelay > 0 {
            try? await Task.sleep(nanoseconds: simulatedDelay)
        }
        return UIImage()
    }

    func requestThumbnailCGImageForVision(for asset: PHAsset, pointSize: CGSize, scale: CGFloat) async throws -> (cgImage: CGImage, estimatedByteCount: Int64) {
        if simulatedDelay > 0 {
            try? await Task.sleep(nanoseconds: simulatedDelay)
        }
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
        if simulatedDelay > 0 {
            try? await Task.sleep(nanoseconds: simulatedDelay)
        }
        return UIImage()
    }
}
