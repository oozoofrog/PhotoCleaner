//
//  PhotoCacheStoreProtocolTests.swift
//  PhotoCleanerTests
//

import Testing
import Foundation
@testable import PhotoCleaner

@Suite("PhotoCacheStoreProtocol Contract")
struct PhotoCacheStoreProtocolTests {
    
    @Test("PhotoCacheStore가 저장소 계약을 준수한다")
    @MainActor
    func photoCacheStoreConformsToProtocol() async throws {
        let store = try PhotoCacheStore.makeInMemory()
        let cacheStore: PhotoCacheStoreProtocol = store
        
        await cacheStore.saveSyncToken("contract-token".data(using: .utf8)!)
        let token = await cacheStore.fetchSyncToken()
        #expect(token == "contract-token".data(using: .utf8))
        
        await cacheStore.insertNewAssets([
            NewAssetInfo(localIdentifier: "asset-1", creationDate: nil, pixelWidth: 100, pixelHeight: 100, mediaSubtypes: 0),
            NewAssetInfo(localIdentifier: "asset-2", creationDate: nil, pixelWidth: 100, pixelHeight: 100, mediaSubtypes: 0)
        ])
        
        let allIds = await cacheStore.fetchAllIdentifiers()
        #expect(allIds == Set(["asset-1", "asset-2"]))
    }
    
    @Test("계약 더블의 핵심 CRUD 시나리오가 동작한다")
    @MainActor
    func contractDoubleSupportsBasicLifecycle() async {
        let store = InMemoryPhotoCacheStoreContractDouble()
        
        await store.insertNewAssets([
            NewAssetInfo(localIdentifier: "asset-1", creationDate: nil, pixelWidth: 100, pixelHeight: 100, mediaSubtypes: 0)
        ])
        
        let pending = await store.fetchPendingAssets(limit: 10)
        #expect(pending.count == 1)
        #expect(pending.first?.scanStatus == .pending)
        
        await store.updateAssetScanResult(
            identifier: "asset-1",
            result: ScanResultInfo(
                hash: "h1",
                byteCount: 123,
                featurePrintData: Data([0x00, 0x01]),
                issues: [
                    CachedIssueDTO(
                        issueType: .screenshot,
                        severity: .info,
                        detectedAt: Date(),
                        fileSize: 123,
                        errorMessage: nil,
                        duplicateGroupId: nil,
                        canRecover: false
                    )
                ]
            )
        )
        
        let scanned = await store.fetchScannedAssetsWithHash()
        #expect(scanned.count == 1)
        #expect(scanned.first?.hash == "h1")
        
        await store.deleteAssets(withIdentifiers: ["asset-1"])
        #expect(await store.fetchAllIdentifiers().isEmpty)
    }
}

final class InMemoryPhotoCacheStoreContractDouble: PhotoCacheStoreProtocol, @unchecked Sendable {
    private var assets: [String: CachedAssetDTO] = [:]
    private var token: Data?
    
    func fetchAllIdentifiers() async -> Set<String> {
        Set(assets.keys)
    }
    
    func fetchPendingAssets(limit: Int) async -> [CachedAssetDTO] {
        assets.values
            .filter { $0.scanStatus == .pending }
            .prefix(limit)
            .map { $0 }
    }
    
    func fetchScannedAssetsWithHash() async -> [AssetHashInfo] {
        assets.values.compactMap { dto in
            guard let hash = dto.resourceHash else { return nil }
            return AssetHashInfo(
                identifier: dto.localIdentifier,
                hash: hash,
                byteCount: dto.resourceByteCount ?? 0
            )
        }
    }
    
    func fetchScannedAssetsWithFeaturePrint() async -> [AssetFeaturePrintInfo] {
        []
    }
    
    func insertNewAssets(_ assets: sending [NewAssetInfo]) async {
        for info in assets {
            self.assets[info.localIdentifier] = CachedAssetDTO(
                localIdentifier: info.localIdentifier,
                creationDate: info.creationDate,
                pixelWidth: info.pixelWidth,
                pixelHeight: info.pixelHeight,
                mediaSubtypes: info.mediaSubtypes,
                scanStatus: .pending,
                resourceHash: nil,
                resourceByteCount: nil
            )
        }
    }
    
    func deleteAssets(withIdentifiers identifiers: Set<String>) async {
        for identifier in identifiers {
            assets.removeValue(forKey: identifier)
        }
    }
    
    func updateAssetScanResult(identifier: String, result: sending ScanResultInfo) async {
        guard let existing = assets[identifier] else { return }
        assets[identifier] = CachedAssetDTO(
            localIdentifier: existing.localIdentifier,
            creationDate: existing.creationDate,
            pixelWidth: existing.pixelWidth,
            pixelHeight: existing.pixelHeight,
            mediaSubtypes: existing.mediaSubtypes,
            scanStatus: .scanned,
            resourceHash: result.hash,
            resourceByteCount: result.byteCount
        )
    }
    
    func markAssetAsFailed(identifier: String, reason: String) async {
        guard let existing = assets[identifier] else { return }
        assets[identifier] = CachedAssetDTO(
            localIdentifier: existing.localIdentifier,
            creationDate: existing.creationDate,
            pixelWidth: existing.pixelWidth,
            pixelHeight: existing.pixelHeight,
            mediaSubtypes: existing.mediaSubtypes,
            scanStatus: .failed,
            resourceHash: nil,
            resourceByteCount: nil
        )
    }
    
    func saveSyncToken(_ token: Data) async {
        self.token = token
    }
    
    func fetchSyncToken() async -> Data? {
        token
    }
    
    func clearAllData() async {
        assets.removeAll()
        token = nil
    }
}
