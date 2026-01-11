//
//  PhotoLibrarySyncServiceTests.swift
//  PhotoCleanerTests
//

import Testing
import Photos
@testable import PhotoCleaner

@Suite("PhotoLibrarySyncService Tests")
@MainActor
struct PhotoLibrarySyncServiceTests {
    
    @Test("동기화 시 새 에셋이 캐시에 추가됨")
    func syncAddsNewAssets() async throws {
        let mockStore = MockPhotoCacheStore()
        let mockLibrary = MockPhotoLibraryProvider(
            assetIdentifiers: ["asset-1", "asset-2", "asset-3"]
        )
        
        let syncService = PhotoLibrarySyncService(
            cacheStore: mockStore,
            libraryProvider: mockLibrary
        )
        
        await syncService.performFullSync()
        
        let cachedIds = await mockStore.fetchAllIdentifiers()
        #expect(cachedIds.count == 3)
        #expect(cachedIds.contains("asset-1"))
        #expect(cachedIds.contains("asset-2"))
        #expect(cachedIds.contains("asset-3"))
    }
    
    @Test("동기화 시 삭제된 에셋이 캐시에서 제거됨")
    func syncRemovesDeletedAssets() async throws {
        let mockStore = MockPhotoCacheStore()
        await mockStore.insertNewAssets([
            NewAssetInfo(localIdentifier: "asset-1", creationDate: nil, pixelWidth: 100, pixelHeight: 100, mediaSubtypes: 0),
            NewAssetInfo(localIdentifier: "asset-2", creationDate: nil, pixelWidth: 100, pixelHeight: 100, mediaSubtypes: 0),
            NewAssetInfo(localIdentifier: "deleted-asset", creationDate: nil, pixelWidth: 100, pixelHeight: 100, mediaSubtypes: 0)
        ])
        
        let mockLibrary = MockPhotoLibraryProvider(
            assetIdentifiers: ["asset-1", "asset-2"]
        )
        
        let syncService = PhotoLibrarySyncService(
            cacheStore: mockStore,
            libraryProvider: mockLibrary
        )
        
        await syncService.performFullSync()
        
        let cachedIds = await mockStore.fetchAllIdentifiers()
        #expect(cachedIds.count == 2)
        #expect(!cachedIds.contains("deleted-asset"))
    }
    
    @Test("이미 캐시된 에셋은 다시 추가되지 않음")
    func syncDoesNotDuplicateExistingAssets() async throws {
        let mockStore = MockPhotoCacheStore()
        await mockStore.insertNewAssets([
            NewAssetInfo(localIdentifier: "existing-asset", creationDate: nil, pixelWidth: 100, pixelHeight: 100, mediaSubtypes: 0)
        ])
        
        await mockStore.resetInsertTracking()
        
        let mockLibrary = MockPhotoLibraryProvider(
            assetIdentifiers: ["existing-asset", "new-asset"]
        )
        
        let syncService = PhotoLibrarySyncService(
            cacheStore: mockStore,
            libraryProvider: mockLibrary
        )
        
        await syncService.performFullSync()
        
        let cachedIds = await mockStore.fetchAllIdentifiers()
        #expect(cachedIds.count == 2)
        
        let insertedCount = await mockStore.getInsertedAssetsCount()
        let lastInsertedId = await mockStore.getLastInsertedAssetId()
        #expect(insertedCount == 1)
        #expect(lastInsertedId == "new-asset")
    }
    
    @Test("동기화 토큰이 저장됨")
    func syncSavesToken() async throws {
        let mockStore = MockPhotoCacheStore()
        let mockLibrary = MockPhotoLibraryProvider(
            assetIdentifiers: ["asset-1"],
            currentToken: "test-token-data".data(using: .utf8)
        )
        
        let syncService = PhotoLibrarySyncService(
            cacheStore: mockStore,
            libraryProvider: mockLibrary
        )
        
        await syncService.performFullSync()
        
        let savedToken = await mockStore.fetchSyncToken()
        #expect(savedToken != nil)
        #expect(savedToken == "test-token-data".data(using: .utf8))
    }
    
    @Test("빈 라이브러리 동기화")
    func syncWithEmptyLibrary() async throws {
        let mockStore = MockPhotoCacheStore()
        await mockStore.insertNewAssets([
            NewAssetInfo(localIdentifier: "old-asset", creationDate: nil, pixelWidth: 100, pixelHeight: 100, mediaSubtypes: 0)
        ])
        
        let mockLibrary = MockPhotoLibraryProvider(assetIdentifiers: [])
        
        let syncService = PhotoLibrarySyncService(
            cacheStore: mockStore,
            libraryProvider: mockLibrary
        )
        
        await syncService.performFullSync()
        
        let cachedIds = await mockStore.fetchAllIdentifiers()
        #expect(cachedIds.isEmpty)
    }
}

@MainActor
final class MockPhotoCacheStore: PhotoCacheStoreProtocol {
    private var assetIds: Set<String> = []
    private var syncToken: Data?
    private var insertedAssetIds: [String] = []
    
    func getInsertedAssetsCount() -> Int {
        insertedAssetIds.count
    }
    
    func getFirstInsertedAssetId() -> String? {
        insertedAssetIds.first
    }
    
    func getLastInsertedAssetId() -> String? {
        insertedAssetIds.last
    }
    
    func resetInsertTracking() {
        insertedAssetIds.removeAll()
    }
    
    func fetchAllIdentifiers() async -> Set<String> {
        assetIds
    }
    
    func fetchPendingAssets(limit: Int) async -> [CachedAssetDTO] {
        []
    }
    
    func fetchScannedAssetsWithHash() async -> [AssetHashInfo] {
        []
    }
    
    func fetchScannedAssetsWithFeaturePrint() async -> [AssetFeaturePrintInfo] {
        []
    }
    
    func insertNewAssets(_ newAssets: sending [NewAssetInfo]) async {
        for asset in newAssets {
            insertedAssetIds.append(asset.localIdentifier)
            assetIds.insert(asset.localIdentifier)
        }
    }
    
    func deleteAssets(withIdentifiers identifiers: Set<String>) async {
        assetIds.subtract(identifiers)
    }
    
    func updateAssetScanResult(identifier: String, result: sending ScanResultInfo) async {}
    
    func markAssetAsFailed(identifier: String, reason: String) async {}
    
    func saveSyncToken(_ token: Data) async {
        syncToken = token
    }
    
    func fetchSyncToken() async -> Data? {
        syncToken
    }
    
    func clearAllData() async {
        assetIds.removeAll()
        syncToken = nil
        insertedAssetIds.removeAll()
    }
}

struct MockPhotoLibraryProvider: PhotoLibraryProviding {
    let assetIdentifiers: [String]
    let currentToken: Data?
    
    init(assetIdentifiers: [String], currentToken: Data? = nil) {
        self.assetIdentifiers = assetIdentifiers
        self.currentToken = currentToken
    }
    
    func fetchAllAssetIdentifiers() async -> Set<String> {
        Set(assetIdentifiers)
    }
    
    func fetchAssetInfo(for identifiers: Set<String>) async -> [NewAssetInfo] {
        identifiers.map { id in
            NewAssetInfo(
                localIdentifier: id,
                creationDate: Date(),
                pixelWidth: 1920,
                pixelHeight: 1080,
                mediaSubtypes: 0
            )
        }
    }
    
    func currentChangeToken() async -> Data? {
        currentToken
    }
}
