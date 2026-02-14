//
//  PhotoCacheStoreContract.swift
//  PhotoCleaner
//

import Foundation
import CoreGraphics

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
