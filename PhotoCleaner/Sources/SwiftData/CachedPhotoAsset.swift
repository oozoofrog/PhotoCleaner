//
//  CachedPhotoAsset.swift
//  PhotoCleaner
//

import Foundation
import SwiftData
import Photos

enum ScanStatus: String, Codable, Sendable {
    case pending
    case scanned
    case failed
}

@Model
final class CachedPhotoAsset {
    @Attribute(.unique) var localIdentifier: String
    var creationDate: Date?
    var pixelWidth: Int
    var pixelHeight: Int
    var mediaSubtypes: UInt
    
    var scanStatusRaw: String = ScanStatus.pending.rawValue
    var failureReason: String?
    var lastScannedAt: Date?
    
    var resourceHash: String?
    var resourceByteCount: Int64?
    var featurePrintData: Data?
    var featurePrintVersion: String?
    
    @Relationship(deleteRule: .cascade, inverse: \CachedPhotoIssue.asset)
    var issues: [CachedPhotoIssue] = []
    
    var scanStatus: ScanStatus {
        get { ScanStatus(rawValue: scanStatusRaw) ?? .pending }
        set { scanStatusRaw = newValue.rawValue }
    }
    
    var aspectRatio: CGFloat {
        guard pixelHeight > 0 else { return 1.0 }
        return CGFloat(pixelWidth) / CGFloat(pixelHeight)
    }
    
    init(
        localIdentifier: String,
        creationDate: Date? = nil,
        pixelWidth: Int,
        pixelHeight: Int,
        mediaSubtypes: UInt
    ) {
        self.localIdentifier = localIdentifier
        self.creationDate = creationDate
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.mediaSubtypes = mediaSubtypes
    }
    
    convenience init(from asset: PHAsset) {
        self.init(
            localIdentifier: asset.localIdentifier,
            creationDate: asset.creationDate,
            pixelWidth: asset.pixelWidth,
            pixelHeight: asset.pixelHeight,
            mediaSubtypes: asset.mediaSubtypes.rawValue
        )
    }
}

@Model
final class CachedPhotoIssue {
    var issueTypeRaw: String
    var severityRaw: Int
    var detectedAt: Date
    var fileSize: Int64?
    var errorMessage: String?
    var duplicateGroupId: String?
    var canRecover: Bool = false
    
    var asset: CachedPhotoAsset?
    
    var issueType: IssueType {
        get { IssueType(rawValue: issueTypeRaw) ?? .corrupted }
        set { issueTypeRaw = newValue.rawValue }
    }
    
    var severity: IssueSeverity {
        get { IssueSeverity(rawValue: severityRaw) ?? .info }
        set { severityRaw = newValue.rawValue }
    }
    
    init(
        issueType: IssueType,
        severity: IssueSeverity,
        detectedAt: Date
    ) {
        self.issueTypeRaw = issueType.rawValue
        self.severityRaw = severity.rawValue
        self.detectedAt = detectedAt
    }
    
    func toIssueMetadata() -> IssueMetadata {
        IssueMetadata(
            fileSize: fileSize,
            errorMessage: errorMessage,
            duplicateGroupId: duplicateGroupId,
            canRecover: canRecover
        )
    }
}

@Model
final class SyncMetadata {
    @Attribute(.unique) var key: String
    var tokenData: Data?
    var lastSyncAt: Date?
    var schemaVersion: Int
    
    init(key: String, tokenData: Data? = nil, lastSyncAt: Date? = nil, schemaVersion: Int = 1) {
        self.key = key
        self.tokenData = tokenData
        self.lastSyncAt = lastSyncAt
        self.schemaVersion = schemaVersion
    }
}
