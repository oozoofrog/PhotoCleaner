//
//  PhotoAssetServiceTests.swift
//  PhotoCleanerTests
//

import Foundation
import Photos
import Testing
@testable import PhotoCleaner

// MARK: - HasResumedBox Tests

@Suite("HasResumedBox 동시성 테스트")
@MainActor
struct HasResumedBoxTests {
    
    @Test("resumeOnce는 한 번만 블록 실행")
    func resumeOnceExecutesOnlyOnce() {
        let box = HasResumedBox()
        var count = 0
        
        box.resumeOnce { count += 1 }
        box.resumeOnce { count += 1 }
        box.resumeOnce { count += 1 }
        
        #expect(count == 1)
    }
    
    @Test("여러 스레드에서 동시 호출해도 한 번만 실행")
    func resumeOnceIsThreadSafe() async {
        let box = HasResumedBox()
        let counter = Counter()
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    box.resumeOnce { counter.increment() }
                }
            }
        }
        
        #expect(counter.value == 1)
    }
}

// MARK: - PhotoImageRequest Tests

@Suite("PhotoImageRequest 프리셋 테스트")
@MainActor
struct PhotoImageRequestTests {
    
    @Test("gridThumbnail 프리셋 값 검증")
    func gridThumbnailPreset() {
        let preset = PhotoImageRequest.gridThumbnail
        
        #expect(preset.deliveryMode == .highQualityFormat)
        #expect(preset.resizeMode == .fast)
        #expect(preset.networkAccessAllowed == false)
    }
    
    @Test("fullQualityNetworkAllowed 프리셋 값 검증")
    func fullQualityNetworkAllowedPreset() {
        let preset = PhotoImageRequest.fullQualityNetworkAllowed
        
        #expect(preset.deliveryMode == .highQualityFormat)
        #expect(preset.resizeMode == .none)
        #expect(preset.networkAccessAllowed == true)
    }
    
    @Test("visionThumbnail 프리셋 값 검증")
    func visionThumbnailPreset() {
        let preset = PhotoImageRequest.visionThumbnail
        
        #expect(preset.deliveryMode == .fastFormat)
        #expect(preset.resizeMode == .fast)
        #expect(preset.networkAccessAllowed == false)
    }
}

// MARK: - PhotoAssetServiceError Tests

@Suite("PhotoAssetServiceError 테스트")
@MainActor
struct PhotoAssetServiceErrorTests {
    
    @Test("imageNotAvailable 에러 메시지")
    func imageNotAvailableErrorDescription() {
        let error = PhotoAssetServiceError.imageNotAvailable
        #expect(error.errorDescription?.isEmpty == false)
    }
    
    @Test("cgImageNotAvailable 에러 메시지")
    func cgImageNotAvailableErrorDescription() {
        let error = PhotoAssetServiceError.cgImageNotAvailable
        #expect(error.errorDescription?.isEmpty == false)
    }
    
    @Test("assetNotFound 에러 메시지에 ID 포함")
    func assetNotFoundErrorDescriptionContainsId() {
        let testId = "test-asset-id"
        let error = PhotoAssetServiceError.assetNotFound(testId)
        #expect(error.errorDescription?.contains(testId) == true)
    }
}

// MARK: - Test Helpers

final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = 0
    
    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }
    
    func increment() {
        lock.lock()
        _value += 1
        lock.unlock()
    }
}
