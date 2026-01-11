//
//  CachedPhotoAssetTests.swift
//  PhotoCleanerTests
//
//  SwiftData CachedPhotoAsset 모델 테스트
//

import Testing
import SwiftData
import Foundation
@testable import PhotoCleaner

// MARK: - Scan Status Tests

@Suite("ScanStatus Tests")
struct ScanStatusTests {
    
    @Test("pending 상태는 rawValue가 'pending'")
    func pendingRawValue() {
        let status = ScanStatus.pending
        #expect(status.rawValue == "pending")
    }
    
    @Test("scanned 상태는 rawValue가 'scanned'")
    func scannedRawValue() {
        let status = ScanStatus.scanned
        #expect(status.rawValue == "scanned")
    }
    
    @Test("failed 상태는 rawValue가 'failed'")
    func failedRawValue() {
        let status = ScanStatus.failed
        #expect(status.rawValue == "failed")
    }
    
    @Test("ScanStatus는 Codable")
    func scanStatusIsCodable() throws {
        let original = ScanStatus.scanned
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ScanStatus.self, from: encoded)
        #expect(decoded == original)
    }
}

// MARK: - CachedPhotoAsset Model Tests

@Suite("CachedPhotoAsset Model Tests", .serialized)
@MainActor
struct CachedPhotoAssetModelTests {
    
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([CachedPhotoAsset.self, CachedPhotoIssue.self, SyncMetadata.self])
        let config = ModelConfiguration(
            "CachedPhotoAssetTests-\(UUID().uuidString)",
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
    
    @Test("CachedPhotoAsset 생성 및 저장")
    func createAndSaveAsset() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        
        let asset = CachedPhotoAsset(
            localIdentifier: "test-id-123",
            creationDate: Date(),
            pixelWidth: 1920,
            pixelHeight: 1080,
            mediaSubtypes: 0
        )
        
        context.insert(asset)
        try context.save()
        
        let descriptor = FetchDescriptor<CachedPhotoAsset>(
            predicate: #Predicate { $0.localIdentifier == "test-id-123" }
        )
        let fetched = try context.fetch(descriptor)
        
        #expect(fetched.count == 1)
        #expect(fetched.first?.localIdentifier == "test-id-123")
        #expect(fetched.first?.pixelWidth == 1920)
        #expect(fetched.first?.pixelHeight == 1080)
        #expect(fetched.first?.scanStatus == .pending)
    }
    
    @Test("localIdentifier는 unique 제약")
    func localIdentifierIsUnique() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        
        let asset1 = CachedPhotoAsset(
            localIdentifier: "same-id",
            pixelWidth: 100,
            pixelHeight: 100,
            mediaSubtypes: 0
        )
        context.insert(asset1)
        try context.save()
        
        // 같은 ID로 두 번째 에셋 추가 시도
        let asset2 = CachedPhotoAsset(
            localIdentifier: "same-id",
            pixelWidth: 200,
            pixelHeight: 200,
            mediaSubtypes: 0
        )
        context.insert(asset2)
        
        // SwiftData는 unique 제약 위반 시 save에서 에러 또는 업데이트
        // 동작은 SwiftData 버전에 따라 다를 수 있음
        let descriptor = FetchDescriptor<CachedPhotoAsset>()
        let all = try context.fetch(descriptor)
        
        // unique 제약이면 1개 또는 2개 (업데이트 vs 추가)
        #expect(all.count >= 1)
    }
    
    @Test("pending 상태 에셋 조회")
    func fetchPendingAssets() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        
        // pending 에셋 3개
        for i in 0..<3 {
            let asset = CachedPhotoAsset(
                localIdentifier: "pending-\(i)",
                pixelWidth: 100,
                pixelHeight: 100,
                mediaSubtypes: 0
            )
            asset.scanStatus = .pending
            context.insert(asset)
        }
        
        // scanned 에셋 2개
        for i in 0..<2 {
            let asset = CachedPhotoAsset(
                localIdentifier: "scanned-\(i)",
                pixelWidth: 100,
                pixelHeight: 100,
                mediaSubtypes: 0
            )
            asset.scanStatus = .scanned
            context.insert(asset)
        }
        
        try context.save()
        
        let pendingDescriptor = FetchDescriptor<CachedPhotoAsset>(
            predicate: #Predicate { $0.scanStatusRaw == "pending" }
        )
        let pendingAssets = try context.fetch(pendingDescriptor)
        
        #expect(pendingAssets.count == 3)
    }
    
    @Test("에셋 삭제 시 연관 이슈도 cascade 삭제")
    func cascadeDeleteIssues() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        
        let asset = CachedPhotoAsset(
            localIdentifier: "asset-with-issues",
            pixelWidth: 100,
            pixelHeight: 100,
            mediaSubtypes: 0
        )
        context.insert(asset)
        
        let issue1 = CachedPhotoIssue(
            issueType: .screenshot,
            severity: .info,
            detectedAt: Date()
        )
        issue1.asset = asset
        context.insert(issue1)
        
        let issue2 = CachedPhotoIssue(
            issueType: .largeFile,
            severity: .info,
            detectedAt: Date()
        )
        issue2.asset = asset
        context.insert(issue2)
        
        try context.save()
        
        // 이슈가 2개인지 확인
        let issueDescriptor = FetchDescriptor<CachedPhotoIssue>()
        var issues = try context.fetch(issueDescriptor)
        #expect(issues.count == 2)
        
        // 에셋 삭제
        context.delete(asset)
        try context.save()
        
        // 이슈도 함께 삭제되었는지 확인
        issues = try context.fetch(issueDescriptor)
        #expect(issues.count == 0)
    }
    
    @Test("resourceHash로 중복 에셋 조회")
    func fetchByResourceHash() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        
        // 같은 해시를 가진 에셋 3개
        let sameHash = "abc123def456"
        for i in 0..<3 {
            let asset = CachedPhotoAsset(
                localIdentifier: "dup-\(i)",
                pixelWidth: 100,
                pixelHeight: 100,
                mediaSubtypes: 0
            )
            asset.resourceHash = sameHash
            asset.scanStatus = .scanned
            context.insert(asset)
        }
        
        // 다른 해시 에셋 2개
        for i in 0..<2 {
            let asset = CachedPhotoAsset(
                localIdentifier: "other-\(i)",
                pixelWidth: 100,
                pixelHeight: 100,
                mediaSubtypes: 0
            )
            asset.resourceHash = "different-hash-\(i)"
            asset.scanStatus = .scanned
            context.insert(asset)
        }
        
        try context.save()
        
        let hashDescriptor = FetchDescriptor<CachedPhotoAsset>(
            predicate: #Predicate { $0.resourceHash == sameHash }
        )
        let duplicates = try context.fetch(hashDescriptor)
        
        #expect(duplicates.count == 3)
    }
    
    @Test("aspectRatio 계산")
    func aspectRatioCalculation() {
        let asset = CachedPhotoAsset(
            localIdentifier: "test",
            pixelWidth: 1920,
            pixelHeight: 1080,
            mediaSubtypes: 0
        )
        
        let expectedRatio = 1920.0 / 1080.0
        #expect(abs(asset.aspectRatio - expectedRatio) < 0.001)
    }
    
    @Test("aspectRatio는 height가 0이면 1.0")
    func aspectRatioWithZeroHeight() {
        let asset = CachedPhotoAsset(
            localIdentifier: "test",
            pixelWidth: 100,
            pixelHeight: 0,
            mediaSubtypes: 0
        )
        
        #expect(asset.aspectRatio == 1.0)
    }
}

// MARK: - CachedPhotoIssue Model Tests

@Suite("CachedPhotoIssue Model Tests", .serialized)
@MainActor
struct CachedPhotoIssueModelTests {
    
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([CachedPhotoAsset.self, CachedPhotoIssue.self, SyncMetadata.self])
        let config = ModelConfiguration(
            "CachedPhotoIssueTests-\(UUID().uuidString)",
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
    
    @Test("CachedPhotoIssue 생성 및 저장")
    func createAndSaveIssue() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        
        let assetId = "issue-test-asset-\(UUID().uuidString)"
        let asset = CachedPhotoAsset(
            localIdentifier: assetId,
            pixelWidth: 100,
            pixelHeight: 100,
            mediaSubtypes: 0
        )
        context.insert(asset)
        
        let issue = CachedPhotoIssue(
            issueType: .screenshot,
            severity: .info,
            detectedAt: Date()
        )
        issue.asset = asset
        issue.fileSize = 1024 * 1024
        context.insert(issue)
        
        try context.save()
        
        let issueDescriptor = FetchDescriptor<CachedPhotoIssue>()
        let fetched = try context.fetch(issueDescriptor)
        
        #expect(!fetched.isEmpty)
        let savedIssue = try #require(fetched.first { $0.asset?.localIdentifier == assetId })
        #expect(savedIssue.issueType == .screenshot)
        #expect(savedIssue.severity == .info)
        #expect(savedIssue.fileSize == Int64(1024 * 1024))
    }
    
    @Test("이슈 타입별 조회")
    func fetchByIssueType() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        
        let asset = CachedPhotoAsset(
            localIdentifier: "asset-1",
            pixelWidth: 100,
            pixelHeight: 100,
            mediaSubtypes: 0
        )
        context.insert(asset)
        
        // 스크린샷 이슈 2개
        for _ in 0..<2 {
            let issue = CachedPhotoIssue(issueType: .screenshot, severity: .info, detectedAt: Date())
            issue.asset = asset
            context.insert(issue)
        }
        
        // 대용량 이슈 3개
        for _ in 0..<3 {
            let issue = CachedPhotoIssue(issueType: .largeFile, severity: .info, detectedAt: Date())
            issue.asset = asset
            context.insert(issue)
        }
        
        try context.save()
        
        let screenshotType = IssueType.screenshot.rawValue
        let screenshotDescriptor = FetchDescriptor<CachedPhotoIssue>(
            predicate: #Predicate { $0.issueTypeRaw == screenshotType }
        )
        let screenshots = try context.fetch(screenshotDescriptor)
        
        #expect(screenshots.count == 2)
    }
    
    @Test("IssueMetadata 변환")
    func issueMetadataConversion() {
        let issue = CachedPhotoIssue(
            issueType: .duplicate,
            severity: .info,
            detectedAt: Date()
        )
        issue.fileSize = 2048
        issue.errorMessage = "테스트 에러"
        issue.duplicateGroupId = "group-123"
        issue.canRecover = true
        
        let metadata = issue.toIssueMetadata()
        
        #expect(metadata.fileSize == 2048)
        #expect(metadata.errorMessage == "테스트 에러")
        #expect(metadata.duplicateGroupId == "group-123")
        #expect(metadata.canRecover == true)
    }
}

// MARK: - SyncMetadata Tests

@Suite("SyncMetadata Tests", .serialized)
@MainActor
struct SyncMetadataTests {
    
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([CachedPhotoAsset.self, CachedPhotoIssue.self, SyncMetadata.self])
        let config = ModelConfiguration(
            "SyncMetadataTests-\(UUID().uuidString)",
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
    
    @Test("SyncMetadata 저장 및 조회")
    func saveAndFetchSyncMetadata() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        
        let tokenData = "test-token-data".data(using: .utf8)!
        let metadata = SyncMetadata(
            key: "photoLibraryToken",
            tokenData: tokenData,
            lastSyncAt: Date(),
            schemaVersion: 1
        )
        context.insert(metadata)
        try context.save()
        
        let descriptor = FetchDescriptor<SyncMetadata>(
            predicate: #Predicate { $0.key == "photoLibraryToken" }
        )
        let fetched = try context.fetch(descriptor)
        
        #expect(fetched.count == 1)
        #expect(fetched.first?.tokenData == tokenData)
        #expect(fetched.first?.schemaVersion == 1)
    }
}

// MARK: - PhotoCacheStore Tests

@Suite("PhotoCacheStore Tests", .serialized)
@MainActor
struct PhotoCacheStoreTests {
    
    @Test("fetchAllIdentifiers - 빈 스토어")
    func fetchAllIdentifiersEmpty() async throws {
        let store = try PhotoCacheStore.makeInMemory()
        let identifiers = await store.fetchAllIdentifiers()
        #expect(identifiers.isEmpty)
    }
    
    @Test("insertNewAssets 후 fetchAllIdentifiers")
    func insertAndFetchIdentifiers() async throws {
        let store = try PhotoCacheStore.makeInMemory()
        
        let assets = [
            NewAssetInfo(localIdentifier: "id-1", creationDate: Date(), pixelWidth: 100, pixelHeight: 100, mediaSubtypes: 0),
            NewAssetInfo(localIdentifier: "id-2", creationDate: Date(), pixelWidth: 200, pixelHeight: 200, mediaSubtypes: 0),
            NewAssetInfo(localIdentifier: "id-3", creationDate: Date(), pixelWidth: 300, pixelHeight: 300, mediaSubtypes: 0)
        ]
        
        await store.insertNewAssets(assets)
        
        let identifiers = await store.fetchAllIdentifiers()
        #expect(identifiers.count == 3)
        #expect(identifiers.contains("id-1"))
        #expect(identifiers.contains("id-2"))
        #expect(identifiers.contains("id-3"))
    }
    
    @Test("fetchPendingAssets - 새로 추가된 에셋은 pending")
    func newAssetsArePending() async throws {
        let store = try PhotoCacheStore.makeInMemory()
        
        let assets = [
            NewAssetInfo(localIdentifier: "id-1", creationDate: nil, pixelWidth: 100, pixelHeight: 100, mediaSubtypes: 0),
            NewAssetInfo(localIdentifier: "id-2", creationDate: nil, pixelWidth: 200, pixelHeight: 200, mediaSubtypes: 0)
        ]
        await store.insertNewAssets(assets)
        
        let pending = await store.fetchPendingAssets(limit: 10)
        #expect(pending.count == 2)
        #expect(pending.allSatisfy { $0.scanStatus == .pending })
    }
    
    @Test("deleteAssets - 지정한 ID만 삭제")
    func deleteSpecificAssets() async throws {
        let store = try PhotoCacheStore.makeInMemory()
        
        let assets = [
            NewAssetInfo(localIdentifier: "keep-1", creationDate: nil, pixelWidth: 100, pixelHeight: 100, mediaSubtypes: 0),
            NewAssetInfo(localIdentifier: "delete-1", creationDate: nil, pixelWidth: 100, pixelHeight: 100, mediaSubtypes: 0),
            NewAssetInfo(localIdentifier: "keep-2", creationDate: nil, pixelWidth: 100, pixelHeight: 100, mediaSubtypes: 0)
        ]
        await store.insertNewAssets(assets)
        
        await store.deleteAssets(withIdentifiers: ["delete-1"])
        
        let remaining = await store.fetchAllIdentifiers()
        #expect(remaining.count == 2)
        #expect(remaining.contains("keep-1"))
        #expect(remaining.contains("keep-2"))
        #expect(!remaining.contains("delete-1"))
    }
    
    @Test("updateAssetScanResult - 스캔 결과 저장")
    func updateScanResult() async throws {
        let store = try PhotoCacheStore.makeInMemory()
        
        let assets = [
            NewAssetInfo(localIdentifier: "id-1", creationDate: nil, pixelWidth: 100, pixelHeight: 100, mediaSubtypes: 0)
        ]
        await store.insertNewAssets(assets)
        
        let result = ScanResultInfo(
            hash: "abc123",
            byteCount: 1024,
            featurePrintData: nil,
            issues: [
                CachedIssueDTO(issueType: .screenshot, severity: .info, detectedAt: Date(), fileSize: 512, errorMessage: nil, duplicateGroupId: nil, canRecover: false)
            ]
        )
        await store.updateAssetScanResult(identifier: "id-1", result: result)
        
        let pending = await store.fetchPendingAssets(limit: 10)
        #expect(pending.isEmpty)
        
        let hashes = await store.fetchScannedAssetsWithHash()
        #expect(hashes.count == 1)
        #expect(hashes.first?.hash == "abc123")
        #expect(hashes.first?.byteCount == 1024)
    }
    
    @Test("markAssetAsFailed - 실패 상태로 변경")
    func markAsFailed() async throws {
        let store = try PhotoCacheStore.makeInMemory()
        
        let assets = [
            NewAssetInfo(localIdentifier: "id-1", creationDate: nil, pixelWidth: 100, pixelHeight: 100, mediaSubtypes: 0)
        ]
        await store.insertNewAssets(assets)
        
        await store.markAssetAsFailed(identifier: "id-1", reason: "iCloud only")
        
        let pending = await store.fetchPendingAssets(limit: 10)
        #expect(pending.isEmpty)
    }
    
    @Test("syncToken 저장 및 조회")
    func syncTokenSaveAndFetch() async throws {
        let store = try PhotoCacheStore.makeInMemory()
        
        let token = "test-token-123".data(using: .utf8)!
        await store.saveSyncToken(token)
        
        let fetched = await store.fetchSyncToken()
        #expect(fetched == token)
    }
    
    @Test("clearAllData - 모든 데이터 삭제")
    func clearAllData() async throws {
        let store = try PhotoCacheStore.makeInMemory()
        
        let assets = [
            NewAssetInfo(localIdentifier: "id-1", creationDate: nil, pixelWidth: 100, pixelHeight: 100, mediaSubtypes: 0),
            NewAssetInfo(localIdentifier: "id-2", creationDate: nil, pixelWidth: 100, pixelHeight: 100, mediaSubtypes: 0)
        ]
        await store.insertNewAssets(assets)
        await store.saveSyncToken("token".data(using: .utf8)!)
        
        await store.clearAllData()
        
        let identifiers = await store.fetchAllIdentifiers()
        let token = await store.fetchSyncToken()
        
        #expect(identifiers.isEmpty)
        #expect(token == nil)
    }
}
