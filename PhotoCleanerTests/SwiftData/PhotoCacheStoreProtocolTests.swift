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

        await cacheStore.saveKeywords(for: "asset-1", keywords: [
            AssetKeywordDTO(
                assetIdentifier: "asset-1",
                keyword: "cat",
                confidence: 0.98,
                languageCode: "en",
                createdAt: Date(),
                isManual: false
            )
        ])

        let keywords = await cacheStore.fetchKeywords(for: "asset-1")
        #expect(keywords.count == 1)
        #expect(keywords.first?.keyword == "cat")

        let summary = await cacheStore.fetchKeywordSummary(limit: 10)
        #expect(summary.contains { $0.keyword == "cat" && $0.assetCount == 1 })
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
    
    @Test("없는 식별자 삭제 호출은 안전하게 무시된다")
    @MainActor
    func deletingUnknownIdentifierIsNoop() async {
        let store = InMemoryPhotoCacheStoreContractDouble()
        
        await store.insertNewAssets([
            NewAssetInfo(localIdentifier: "asset-1", creationDate: nil, pixelWidth: 100, pixelHeight: 100, mediaSubtypes: 0)
        ])
        
        await store.deleteAssets(withIdentifiers: ["not-found"])
        
        #expect(await store.fetchAllIdentifiers() == Set(["asset-1"]))
    }
    
    @Test("해시 조회는 해시가 없는 항목을 제외한다")
    @MainActor
    func fetchScannedAssetsWithHashFiltersMissingValues() async {
        let store = InMemoryPhotoCacheStoreContractDouble()
        
        await store.insertNewAssets([
            NewAssetInfo(localIdentifier: "hashed", creationDate: nil, pixelWidth: 100, pixelHeight: 100, mediaSubtypes: 0),
            NewAssetInfo(localIdentifier: "missing", creationDate: nil, pixelWidth: 100, pixelHeight: 100, mediaSubtypes: 0)
        ])
        
        await store.updateAssetScanResult(identifier: "hashed", result: ScanResultInfo(
            hash: "hash-value",
            byteCount: 1024,
            featurePrintData: nil,
            issues: []
        ))
        
        let hashedAssets = await store.fetchScannedAssetsWithHash()
        #expect(hashedAssets.count == 1)
        #expect(hashedAssets.first?.identifier == "hashed")
        #expect(hashedAssets.first?.hash == "hash-value")
    }

    @Test("키워드 요약은 에셋 단위로 집계된다")
    @MainActor
    func keywordSummaryAggregatesByAsset() async {
        let store = InMemoryPhotoCacheStoreContractDouble()

        await store.insertNewAssets([
            NewAssetInfo(localIdentifier: "asset-1", creationDate: nil, pixelWidth: 100, pixelHeight: 100, mediaSubtypes: 0),
            NewAssetInfo(localIdentifier: "asset-2", creationDate: nil, pixelWidth: 100, pixelHeight: 100, mediaSubtypes: 0)
        ])

        let now = Date()
        await store.saveKeywords(for: "asset-1", keywords: [
            AssetKeywordDTO(assetIdentifier: "asset-1", keyword: "cat", confidence: 0.99, languageCode: "en", createdAt: now, isManual: false),
            AssetKeywordDTO(assetIdentifier: "asset-1", keyword: "pet", confidence: 0.88, languageCode: "en", createdAt: now, isManual: false)
        ])
        await store.saveKeywords(for: "asset-2", keywords: [
            AssetKeywordDTO(assetIdentifier: "asset-2", keyword: "cat", confidence: 0.97, languageCode: "en", createdAt: now, isManual: false)
        ])

        let summary = await store.fetchKeywordSummary(limit: 10)
        let cat = summary.first { $0.keyword == "cat" && $0.languageCode == "en" }
        let pet = summary.first { $0.keyword == "pet" && $0.languageCode == "en" }

        #expect(cat?.assetCount == 2)
        #expect(pet?.assetCount == 1)
    }
}

final class InMemoryPhotoCacheStoreContractDouble: PhotoCacheStoreProtocol, @unchecked Sendable {
    private var assets: [String: CachedAssetDTO] = [:]
    private var token: Data?
    private var keywordsByAsset: [String: [AssetKeywordDTO]] = [:]
    
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

    func saveKeywords(for identifier: String, keywords: sending [AssetKeywordDTO]) async {
        keywordsByAsset[identifier] = keywords.map { keyword in
            AssetKeywordDTO(
                assetIdentifier: identifier,
                keyword: keyword.keyword,
                confidence: keyword.confidence,
                languageCode: keyword.languageCode,
                createdAt: keyword.createdAt,
                isManual: keyword.isManual
            )
        }
    }

    func fetchKeywords(for identifier: String) async -> [AssetKeywordDTO] {
        keywordsByAsset[identifier] ?? []
    }

    func fetchKeywordSummary(limit: Int) async -> [KeywordSummaryDTO] {
        guard limit >= 0 else { return [] }

        var groupedAssetIds: [String: Set<String>] = [:]
        var groupedMetadata: [String: (keyword: String, languageCode: String, updatedAt: Date)] = [:]

        for (assetIdentifier, keywords) in keywordsByAsset {
            for keyword in keywords {
                let key = "\(keyword.keyword)|\(keyword.languageCode)"
                groupedAssetIds[key, default: []].insert(assetIdentifier)
                if let existing = groupedMetadata[key] {
                    groupedMetadata[key] = (
                        keyword: existing.keyword,
                        languageCode: existing.languageCode,
                        updatedAt: max(existing.updatedAt, keyword.createdAt)
                    )
                } else {
                    groupedMetadata[key] = (
                        keyword: keyword.keyword,
                        languageCode: keyword.languageCode,
                        updatedAt: keyword.createdAt
                    )
                }
            }
        }

        let summary = groupedAssetIds.compactMap { key, assetIds -> KeywordSummaryDTO? in
            guard let metadata = groupedMetadata[key] else { return nil }
            return KeywordSummaryDTO(
                keyword: metadata.keyword,
                languageCode: metadata.languageCode,
                assetCount: assetIds.count,
                updatedAt: metadata.updatedAt
            )
        }
        .sorted {
            if $0.assetCount == $1.assetCount {
                return $0.keyword < $1.keyword
            }
            return $0.assetCount > $1.assetCount
        }

        return Array(summary.prefix(limit))
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
        keywordsByAsset.removeAll()
    }
}
