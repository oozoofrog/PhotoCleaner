//
//  PhotoCacheStore.swift
//  PhotoCleaner
//

import Foundation
import SwiftData
import Photos

struct CachedAssetDTO: Sendable {
    let localIdentifier: String
    let creationDate: Date?
    let pixelWidth: Int
    let pixelHeight: Int
    let mediaSubtypes: UInt
    let scanStatus: ScanStatus
    let resourceHash: String?
    let resourceByteCount: Int64?
    
    var aspectRatio: CGFloat {
        guard pixelHeight > 0 else { return 1.0 }
        return CGFloat(pixelWidth) / CGFloat(pixelHeight)
    }
}

struct CachedIssueDTO: Sendable {
    let issueType: IssueType
    let severity: IssueSeverity
    let detectedAt: Date
    let fileSize: Int64?
    let errorMessage: String?
    let duplicateGroupId: String?
    let canRecover: Bool
}

struct AssetHashInfo: Sendable {
    let identifier: String
    let hash: String
    let byteCount: Int64
}

struct AssetFeaturePrintInfo: Sendable {
    let identifier: String
    let featurePrintData: Data
    let byteCount: Int64
}

struct NewAssetInfo: Sendable {
    let localIdentifier: String
    let creationDate: Date?
    let pixelWidth: Int
    let pixelHeight: Int
    let mediaSubtypes: UInt
}

struct ScanResultInfo: Sendable {
    let hash: String?
    let byteCount: Int64?
    let featurePrintData: Data?
    let issues: [CachedIssueDTO]
}

protocol PhotoCacheStoreProtocol: Sendable {
    func fetchAllIdentifiers() async -> Set<String>
    func fetchPendingAssets(limit: Int) async -> [CachedAssetDTO]
    func fetchScannedAssetsWithHash() async -> [AssetHashInfo]
    func fetchScannedAssetsWithFeaturePrint() async -> [AssetFeaturePrintInfo]
    func insertNewAssets(_ assets: sending [NewAssetInfo]) async
    func deleteAssets(withIdentifiers identifiers: Set<String>) async
    func updateAssetScanResult(identifier: String, result: sending ScanResultInfo) async
    func markAssetAsFailed(identifier: String, reason: String) async
    func saveSyncToken(_ token: Data) async
    func fetchSyncToken() async -> Data?
    func clearAllData() async
}

@ModelActor
actor PhotoCacheStore: PhotoCacheStoreProtocol {
    
    nonisolated private static let syncMetadataKey = "photoLibraryToken"
    nonisolated private static let currentSchemaVersion = 1
    
    func fetchAllIdentifiers() async -> Set<String> {
        let descriptor = FetchDescriptor<CachedPhotoAsset>()
        do {
            let assets = try modelContext.fetch(descriptor)
            return Set(assets.map(\.localIdentifier))
        } catch {
            return []
        }
    }
    
    func fetchPendingAssets(limit: Int) async -> [CachedAssetDTO] {
        let pendingStatus = ScanStatus.pending.rawValue
        var descriptor = FetchDescriptor<CachedPhotoAsset>(
            predicate: #Predicate { $0.scanStatusRaw == pendingStatus }
        )
        descriptor.fetchLimit = limit
        
        do {
            let assets = try modelContext.fetch(descriptor)
            return assets.map { $0.toDTO() }
        } catch {
            return []
        }
    }
    
    func fetchScannedAssetsWithHash() async -> [AssetHashInfo] {
        let scannedStatus = ScanStatus.scanned.rawValue
        let descriptor = FetchDescriptor<CachedPhotoAsset>(
            predicate: #Predicate { $0.scanStatusRaw == scannedStatus && $0.resourceHash != nil }
        )
        
        do {
            let assets = try modelContext.fetch(descriptor)
            return assets.compactMap { asset in
                guard let hash = asset.resourceHash else { return nil }
                return AssetHashInfo(
                    identifier: asset.localIdentifier,
                    hash: hash,
                    byteCount: asset.resourceByteCount ?? 0
                )
            }
        } catch {
            return []
        }
    }
    
    func fetchScannedAssetsWithFeaturePrint() async -> [AssetFeaturePrintInfo] {
        let scannedStatus = ScanStatus.scanned.rawValue
        let descriptor = FetchDescriptor<CachedPhotoAsset>(
            predicate: #Predicate { $0.scanStatusRaw == scannedStatus && $0.featurePrintData != nil }
        )
        
        do {
            let assets = try modelContext.fetch(descriptor)
            return assets.compactMap { asset in
                guard let fpData = asset.featurePrintData else { return nil }
                return AssetFeaturePrintInfo(
                    identifier: asset.localIdentifier,
                    featurePrintData: fpData,
                    byteCount: asset.resourceByteCount ?? 0
                )
            }
        } catch {
            return []
        }
    }
    
    func insertNewAssets(_ assets: sending [NewAssetInfo]) async {
        for info in assets {
            let asset = CachedPhotoAsset(
                localIdentifier: info.localIdentifier,
                creationDate: info.creationDate,
                pixelWidth: info.pixelWidth,
                pixelHeight: info.pixelHeight,
                mediaSubtypes: info.mediaSubtypes
            )
            modelContext.insert(asset)
        }
        try? modelContext.save()
    }
    
    func deleteAssets(withIdentifiers identifiers: Set<String>) async {
        for identifier in identifiers {
            let descriptor = FetchDescriptor<CachedPhotoAsset>(
                predicate: #Predicate { $0.localIdentifier == identifier }
            )
            if let assets = try? modelContext.fetch(descriptor) {
                for asset in assets {
                    modelContext.delete(asset)
                }
            }
        }
        try? modelContext.save()
    }
    
    func updateAssetScanResult(identifier: String, result: sending ScanResultInfo) async {
        let descriptor = FetchDescriptor<CachedPhotoAsset>(
            predicate: #Predicate { $0.localIdentifier == identifier }
        )
        
        guard let asset = try? modelContext.fetch(descriptor).first else { return }
        
        asset.resourceHash = result.hash
        asset.resourceByteCount = result.byteCount
        asset.featurePrintData = result.featurePrintData
        asset.featurePrintVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        asset.scanStatus = .scanned
        asset.lastScannedAt = Date()
        
        for issueDTO in result.issues {
            let issue = CachedPhotoIssue(
                issueType: issueDTO.issueType,
                severity: issueDTO.severity,
                detectedAt: issueDTO.detectedAt
            )
            issue.fileSize = issueDTO.fileSize
            issue.errorMessage = issueDTO.errorMessage
            issue.duplicateGroupId = issueDTO.duplicateGroupId
            issue.canRecover = issueDTO.canRecover
            issue.asset = asset
            modelContext.insert(issue)
        }
        
        try? modelContext.save()
    }
    
    func markAssetAsFailed(identifier: String, reason: String) async {
        let descriptor = FetchDescriptor<CachedPhotoAsset>(
            predicate: #Predicate { $0.localIdentifier == identifier }
        )
        
        guard let asset = try? modelContext.fetch(descriptor).first else { return }
        
        asset.scanStatus = .failed
        asset.failureReason = reason
        asset.lastScannedAt = Date()
        
        try? modelContext.save()
    }
    
    func saveSyncToken(_ token: Data) async {
        let key = Self.syncMetadataKey
        let descriptor = FetchDescriptor<SyncMetadata>(
            predicate: #Predicate<SyncMetadata> { $0.key == key }
        )
        
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.tokenData = token
            existing.lastSyncAt = Date()
        } else {
            let metadata = SyncMetadata(
                key: Self.syncMetadataKey,
                tokenData: token,
                lastSyncAt: Date(),
                schemaVersion: Self.currentSchemaVersion
            )
            modelContext.insert(metadata)
        }
        
        try? modelContext.save()
    }
    
    func fetchSyncToken() async -> Data? {
        let key = Self.syncMetadataKey
        let descriptor = FetchDescriptor<SyncMetadata>(
            predicate: #Predicate<SyncMetadata> { $0.key == key }
        )
        
        return try? modelContext.fetch(descriptor).first?.tokenData
    }
    
    func clearAllData() async {
        try? modelContext.delete(model: CachedPhotoAsset.self)
        try? modelContext.delete(model: CachedPhotoIssue.self)
        try? modelContext.delete(model: SyncMetadata.self)
        try? modelContext.save()
    }
}

extension CachedPhotoAsset {
    func toDTO() -> CachedAssetDTO {
        CachedAssetDTO(
            localIdentifier: localIdentifier,
            creationDate: creationDate,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            mediaSubtypes: mediaSubtypes,
            scanStatus: scanStatus,
            resourceHash: resourceHash,
            resourceByteCount: resourceByteCount
        )
    }
}

extension PhotoCacheStore {
    @MainActor
    static func makeInMemory() throws -> PhotoCacheStore {
        let schema = Schema([CachedPhotoAsset.self, CachedPhotoIssue.self, SyncMetadata.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return PhotoCacheStore(modelContainer: container)
    }
    
    @MainActor
    static func makeDefault() throws -> PhotoCacheStore {
        let schema = Schema([CachedPhotoAsset.self, CachedPhotoIssue.self, SyncMetadata.self])
        let container = try ModelContainer(for: schema)
        return PhotoCacheStore(modelContainer: container)
    }
}
