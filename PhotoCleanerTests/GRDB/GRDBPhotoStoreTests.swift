//
//  GRDBPhotoStoreTests.swift
//  PhotoCleanerTests
//

import Foundation
import Testing

@testable import PhotoCleaner

@Suite("GRDBPhotoStore Tests", .serialized)
@MainActor
struct GRDBPhotoStoreTests {
    
    @Test("in-memory GRDBPhotoStore는 빈 상태로 시작한다")
    func startsEmpty() async throws {
        let store = try GRDBPhotoStore.makeInMemory()
        
        #expect(await store.fetchAllIdentifiers().isEmpty)
        #expect(await store.fetchKeywordSummary(limit: 10).isEmpty)
    }
    
    @Test("새로운 에셋은 insert 후 식별자로 조회된다")
    func insertAndFetchAllIdentifiers() async throws {
        let store = try GRDBPhotoStore.makeInMemory()
        
        await store.insertNewAssets([
            NewAssetInfo(localIdentifier: "asset-1", creationDate: nil, pixelWidth: 1024, pixelHeight: 768, mediaSubtypes: 0),
            NewAssetInfo(localIdentifier: "asset-2", creationDate: nil, pixelWidth: 1920, pixelHeight: 1080, mediaSubtypes: 0),
            NewAssetInfo(localIdentifier: "asset-3", creationDate: nil, pixelWidth: 640, pixelHeight: 480, mediaSubtypes: 0)
        ])
        
        let allIdentifiers = await store.fetchAllIdentifiers()
        #expect(allIdentifiers == Set(["asset-1", "asset-2", "asset-3"]))
    }
    
    @Test("deleteAssets는 지정한 식별자만 삭제한다")
    func deleteSpecificIdentifiers() async throws {
        let store = try GRDBPhotoStore.makeInMemory()
        
        await store.insertNewAssets([
            NewAssetInfo(localIdentifier: "keep-1", creationDate: nil, pixelWidth: 100, pixelHeight: 100, mediaSubtypes: 0),
            NewAssetInfo(localIdentifier: "delete-me", creationDate: nil, pixelWidth: 100, pixelHeight: 100, mediaSubtypes: 0),
            NewAssetInfo(localIdentifier: "keep-2", creationDate: nil, pixelWidth: 100, pixelHeight: 100, mediaSubtypes: 0)
        ])
        
        await store.deleteAssets(withIdentifiers: ["delete-me"])
        
        let allIdentifiers = await store.fetchAllIdentifiers()
        #expect(allIdentifiers == Set(["keep-1", "keep-2"]))
    }
    
    @Test("updateAssetScanResult는 해시와 feature print를 저장한다")
    func updateScanResultStoresHashAndFeaturePrint() async throws {
        let store = try GRDBPhotoStore.makeInMemory()
        
        await store.insertNewAssets([
            NewAssetInfo(localIdentifier: "asset-1", creationDate: nil, pixelWidth: 100, pixelHeight: 100, mediaSubtypes: 0)
        ])
        
        await store.updateAssetScanResult(
            identifier: "asset-1",
            result: ScanResultInfo(
                hash: "hash-1",
                byteCount: 512,
                featurePrintData: Data([0x00, 0x01]),
                issues: [
                    CachedIssueDTO(
                        issueType: .corrupted,
                        severity: .warning,
                        detectedAt: Date(),
                        fileSize: 512,
                        errorMessage: nil,
                        duplicateGroupId: nil,
                        canRecover: false
                    )
                ]
            )
        )
        
        let hashedAssets = await store.fetchScannedAssetsWithHash()
        #expect(hashedAssets.count == 1)
        #expect(hashedAssets.first?.identifier == "asset-1")
        #expect(hashedAssets.first?.hash == "hash-1")
        #expect(hashedAssets.first?.byteCount == 512)
        
        let featurePrintAssets = await store.fetchScannedAssetsWithFeaturePrint()
        #expect(featurePrintAssets.count == 1)
        #expect(featurePrintAssets.first?.identifier == "asset-1")
        #expect(featurePrintAssets.first?.featurePrintData == Data([0x00, 0x01]))
    }
    
    @Test("saveKeywords는 기존 키워드를 자산 단위로 교체한다")
    func saveKeywordsReplacesExistingKeywordsForAsset() async throws {
        let store = try GRDBPhotoStore.makeInMemory()
        
        await store.insertNewAssets([
            NewAssetInfo(localIdentifier: "asset-1", creationDate: nil, pixelWidth: 100, pixelHeight: 100, mediaSubtypes: 0)
        ])
        
        await store.saveKeywords(for: "asset-1", keywords: [
            AssetKeywordDTO(
                assetIdentifier: "asset-1",
                keyword: "cat",
                confidence: 0.98,
                languageCode: "en",
                createdAt: Date(),
                isManual: false
            )
        ])
        
        await store.saveKeywords(for: "asset-1", keywords: [
            AssetKeywordDTO(
                assetIdentifier: "asset-1",
                keyword: "dog",
                confidence: 0.97,
                languageCode: "en",
                createdAt: Date(),
                isManual: true
            )
        ])
        
        let keywords = await store.fetchKeywords(for: "asset-1")
        #expect(keywords.count == 1)
        #expect(keywords.first?.keyword == "dog")
    }
    
    @Test("fetchKeywords는 confidence 내림차순, keyword 오름차순으로 정렬된다")
    func keywordsAreSortedByConfidenceThenName() async throws {
        let store = try GRDBPhotoStore.makeInMemory()
        
        await store.insertNewAssets([
            NewAssetInfo(localIdentifier: "asset-1", creationDate: nil, pixelWidth: 100, pixelHeight: 100, mediaSubtypes: 0)
        ])
        
        await store.saveKeywords(for: "asset-1", keywords: [
            AssetKeywordDTO(
                assetIdentifier: "asset-1",
                keyword: "banana",
                confidence: 0.82,
                languageCode: "en",
                createdAt: Date(),
                isManual: false
            ),
            AssetKeywordDTO(
                assetIdentifier: "asset-1",
                keyword: "apple",
                confidence: 0.95,
                languageCode: "en",
                createdAt: Date(),
                isManual: false
            ),
            AssetKeywordDTO(
                assetIdentifier: "asset-1",
                keyword: "cherry",
                confidence: 0.95,
                languageCode: "en",
                createdAt: Date(),
                isManual: false
            )
        ])
        
        let keywords = await store.fetchKeywords(for: "asset-1")
        #expect(keywords.count == 3)
        #expect(keywords[0].keyword == "apple")
        #expect(keywords[1].keyword == "cherry")
        #expect(keywords[2].keyword == "banana")
    }
    
    @Test("키워드 요약은 에셋 단위로 집계한다")
    func keywordSummaryAggregatesByAssetAndLanguage() async throws {
        let store = try GRDBPhotoStore.makeInMemory()
        
        await store.insertNewAssets([
            NewAssetInfo(localIdentifier: "asset-1", creationDate: nil, pixelWidth: 100, pixelHeight: 100, mediaSubtypes: 0),
            NewAssetInfo(localIdentifier: "asset-2", creationDate: nil, pixelWidth: 100, pixelHeight: 100, mediaSubtypes: 0),
            NewAssetInfo(localIdentifier: "asset-3", creationDate: nil, pixelWidth: 100, pixelHeight: 100, mediaSubtypes: 0)
        ])
        
        let now = Date()
        await store.saveKeywords(for: "asset-1", keywords: [
            AssetKeywordDTO(assetIdentifier: "asset-1", keyword: "cat", confidence: 0.95, languageCode: "en", createdAt: now, isManual: false),
            AssetKeywordDTO(assetIdentifier: "asset-1", keyword: "pet", confidence: 0.90, languageCode: "en", createdAt: now, isManual: false)
        ])
        await store.saveKeywords(for: "asset-2", keywords: [
            AssetKeywordDTO(assetIdentifier: "asset-2", keyword: "cat", confidence: 0.90, languageCode: "en", createdAt: now, isManual: false),
            AssetKeywordDTO(assetIdentifier: "asset-2", keyword: "고양이", confidence: 0.90, languageCode: "ko", createdAt: now, isManual: false)
        ])
        await store.saveKeywords(for: "asset-3", keywords: [
            AssetKeywordDTO(assetIdentifier: "asset-3", keyword: "cat", confidence: 0.88, languageCode: "en", createdAt: now, isManual: false)
        ])
        
        let summary = await store.fetchKeywordSummary(limit: 10)
        let catSummary = summary.first { $0.keyword == "cat" && $0.languageCode == "en" }
        let koSummary = summary.first { $0.keyword == "고양이" && $0.languageCode == "ko" }
        let petSummary = summary.first { $0.keyword == "pet" && $0.languageCode == "en" }
        
        #expect(catSummary?.assetCount == 3)
        #expect(koSummary?.assetCount == 1)
        #expect(petSummary?.assetCount == 1)
    }
}
