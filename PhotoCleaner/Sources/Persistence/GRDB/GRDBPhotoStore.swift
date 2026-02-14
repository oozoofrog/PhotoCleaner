//
//  GRDBPhotoStore.swift
//  PhotoCleaner
//

import Foundation
import GRDB

final class GRDBPhotoStore: PhotoCacheStoreProtocol, @unchecked Sendable {
    private let databaseManager: DatabaseManager

    private static let photoAssetsTable = DatabaseMigrations.photoAssetsTable
    private static let photoIssuesTable = DatabaseMigrations.photoIssuesTable
    private static let photoKeywordsTable = DatabaseMigrations.photoKeywordsTable
    private static let keywordSummaryTable = DatabaseMigrations.keywordSummaryTable
    private static let syncMetadataTable = DatabaseMigrations.syncMetadataTable
    private static let syncMetadataKey = DatabaseMigrations.syncMetadataKey
    private static let currentSchemaVersion = DatabaseMigrations.currentSchemaVersion

    init(databaseManager: DatabaseManager) {
        self.databaseManager = databaseManager
    }

    static func makeInMemory() async throws -> GRDBPhotoStore {
        let manager = try DatabaseManager.makeInMemory()
        return GRDBPhotoStore(databaseManager: manager)
    }

    static func makeDefault() async throws -> GRDBPhotoStore {
        let manager = try DatabaseManager.makeDefault()
        return GRDBPhotoStore(databaseManager: manager)
    }

    func fetchAllIdentifiers() async -> Set<String> {
        let tableName = Self.photoAssetsTable
        let rows: [String]? = try? databaseManager.read { db in
            try String.fetchAll(db, sql: "SELECT local_identifier FROM \(tableName)")
        }
        return Set(rows ?? [])
    }

    func fetchPendingAssets(limit: Int) async -> [CachedAssetDTO] {
        guard limit >= 0 else { return [] }
        let tableName = Self.photoAssetsTable

        let rows = try? databaseManager.read { db in
            let query = """
                SELECT
                    local_identifier,
                    creation_date,
                    pixel_width,
                    pixel_height,
                    media_subtypes,
                    scan_status,
                    resource_hash,
                    resource_byte_count
                FROM \(tableName)
                WHERE scan_status = ?
                LIMIT ?
            """
            let result: [Row] = try Row.fetchAll(db, sql: query, arguments: [ScanStatus.pending.rawValue, limit])
            return result.map { row in
                let localIdentifier: String = row["local_identifier"] as String
                let creationSeconds: Int64? = row["creation_date"] as Int64?
                let pixelWidth: Int64 = row["pixel_width"] as Int64? ?? 0
                let pixelHeight: Int64 = row["pixel_height"] as Int64? ?? 0
                let mediaSubtypes: Int64 = row["media_subtypes"] as Int64? ?? 0
                let scanStatusRaw: String = row["scan_status"] as String
                let resourceHash: String? = row["resource_hash"] as String?
                let byteCount: Int64? = row["resource_byte_count"] as Int64?

                return CachedAssetDTO(
                    localIdentifier: localIdentifier,
                    creationDate: Self.date(fromSecondsSince1970: creationSeconds),
                    pixelWidth: Int(pixelWidth),
                    pixelHeight: Int(pixelHeight),
                    mediaSubtypes: UInt(mediaSubtypes),
                    scanStatus: ScanStatus(rawValue: scanStatusRaw) ?? .pending,
                    resourceHash: resourceHash,
                    resourceByteCount: byteCount
                )
            }
        }

        return rows ?? []
    }

    func fetchScannedAssetsWithHash() async -> [AssetHashInfo] {
        let tableName = Self.photoAssetsTable

        let rows: [AssetHashInfo]? = try? databaseManager.read { db in
            let result: [Row] = try Row.fetchAll(
                db,
                sql: "SELECT local_identifier, resource_hash, resource_byte_count FROM \(tableName) WHERE scan_status = ? AND resource_hash IS NOT NULL",
                arguments: [ScanStatus.scanned.rawValue]
            )
            var assets: [AssetHashInfo] = []
            for row in result {
                guard let hash: String = row["resource_hash"] as String? else {
                    continue
                }
                let identifier: String = row["local_identifier"] as String
                let byteCount: Int64 = row["resource_byte_count"] as Int64? ?? 0

                assets.append(AssetHashInfo(
                    identifier: identifier,
                    hash: hash,
                    byteCount: byteCount
                ))
            }
            return assets
        }

        return rows ?? []
    }

    func fetchScannedAssetsWithFeaturePrint() async -> [AssetFeaturePrintInfo] {
        let tableName = Self.photoAssetsTable

        let rows: [AssetFeaturePrintInfo]? = try? databaseManager.read { db in
            let result: [Row] = try Row.fetchAll(
                db,
                sql: "SELECT local_identifier, feature_print_data, resource_byte_count FROM \(tableName) WHERE scan_status = ? AND feature_print_data IS NOT NULL",
                arguments: [ScanStatus.scanned.rawValue]
            )
            var assets: [AssetFeaturePrintInfo] = []
            for row in result {
                guard let data: Data = row["feature_print_data"] as Data? else {
                    continue
                }
                let identifier: String = row["local_identifier"] as String
                let byteCount: Int64 = row["resource_byte_count"] as Int64? ?? 0

                assets.append(AssetFeaturePrintInfo(
                    identifier: identifier,
                    featurePrintData: data,
                    byteCount: byteCount
                ))
            }
            return assets
        }

        return rows ?? []
    }

    func insertNewAssets(_ assets: sending [NewAssetInfo]) async {
        guard !assets.isEmpty else { return }
        let tableName = Self.photoAssetsTable

        try? databaseManager.write { db in
            for info in assets {
                try db.execute(
                    sql: """
                        INSERT OR IGNORE INTO \(tableName) (
                            local_identifier, creation_date, pixel_width, pixel_height, media_subtypes, scan_status
                        ) VALUES (?, ?, ?, ?, ?, ?)
                    """,
                    arguments: [
                        info.localIdentifier,
                        Self.secondsSince1970(from: info.creationDate),
                        info.pixelWidth,
                        info.pixelHeight,
                        Int64(info.mediaSubtypes),
                        ScanStatus.pending.rawValue
                    ]
                )
            }
        }
    }

    func deleteAssets(withIdentifiers identifiers: Set<String>) async {
        let tableName = Self.photoAssetsTable
        let targetIdentifiers = Array(identifiers)

        guard !targetIdentifiers.isEmpty else { return }

        try? databaseManager.write { db in
            let placeholders = Array(repeating: "?", count: targetIdentifiers.count).joined(separator: ", ")
            let sql = "DELETE FROM \(tableName) WHERE local_identifier IN (\(placeholders))"
            try db.execute(sql: sql, arguments: StatementArguments(targetIdentifiers))
        }
    }

    func updateAssetScanResult(identifier: String, result: sending ScanResultInfo) async {
        let assetsTable = Self.photoAssetsTable
        let issuesTable = Self.photoIssuesTable

        try? databaseManager.write { db in
            guard let _ = try Row.fetchOne(
                db,
                sql: "SELECT local_identifier FROM \(assetsTable) WHERE local_identifier = ?",
                arguments: [identifier]
            ) else {
                return
            }

            let featurePrintVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            let lastScannedAt = Int64(Date().timeIntervalSince1970)

            try db.execute(
                sql: """
                    UPDATE \(assetsTable)
                    SET
                        scan_status = ?,
                        resource_hash = ?,
                        resource_byte_count = ?,
                        feature_print_data = ?,
                        feature_print_version = ?,
                        last_scanned_at = ?,
                        failure_reason = NULL
                    WHERE local_identifier = ?
                """,
                arguments: [
                    ScanStatus.scanned.rawValue,
                    result.hash,
                    result.byteCount,
                    result.featurePrintData,
                    featurePrintVersion,
                    lastScannedAt,
                    identifier
                ]
            )

            try db.execute(
                sql: "DELETE FROM \(issuesTable) WHERE asset_identifier = ?",
                arguments: [identifier]
            )

            for issue in result.issues {
                try db.execute(
                    sql: """
                        INSERT INTO \(issuesTable)
                            (asset_identifier, issue_type, severity, detected_at, file_size, error_message, duplicate_group_id, can_recover)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    arguments: [
                        identifier,
                        issue.issueType.rawValue,
                        issue.severity.rawValue,
                        Int64(Date().timeIntervalSince1970),
                        issue.fileSize,
                        issue.errorMessage,
                        issue.duplicateGroupId,
                        issue.canRecover ? 1 : 0
                    ]
                )
            }
        }
    }

    func markAssetAsFailed(identifier: String, reason: String) async {
        let tableName = Self.photoAssetsTable

        try? databaseManager.write { db in
            try db.execute(
                sql: "UPDATE \(tableName) SET scan_status = ?, failure_reason = ?, last_scanned_at = ? WHERE local_identifier = ?",
                arguments: [
                    ScanStatus.failed.rawValue,
                    reason,
                    Int64(Date().timeIntervalSince1970),
                    identifier
                ]
            )
        }
    }

    func saveSyncToken(_ token: Data) async {
        let metadataTable = Self.syncMetadataTable
        let key = Self.syncMetadataKey
        let schemaVersion = Self.currentSchemaVersion
        let now = Int64(Date().timeIntervalSince1970)

        try? databaseManager.write { db in
            guard let _ = try Row.fetchOne(
                db,
                sql: "SELECT key FROM \(metadataTable) WHERE key = ?",
                arguments: [key]
            ) else {
                try db.execute(
                    sql: "INSERT INTO \(metadataTable) (key, token_data, last_sync_at, schema_version) VALUES (?, ?, ?, ?)",
                    arguments: [key, token, now, schemaVersion]
                )
                return
            }

            try db.execute(
                sql: "UPDATE \(metadataTable) SET token_data = ?, last_sync_at = ?, schema_version = ? WHERE key = ?",
                arguments: [token, now, schemaVersion, key]
            )
        }
    }

    func fetchSyncToken() async -> Data? {
        let metadataTable = Self.syncMetadataTable
        let key = Self.syncMetadataKey

        return (try? databaseManager.read { db in
            if let row = try Row.fetchOne(
                db,
                sql: "SELECT token_data FROM \(metadataTable) WHERE key = ?",
                arguments: [key]
            ) {
                return row["token_data"] as Data?
            }
            return nil
        }) ?? nil
    }

    func clearAllData() async {
        let issuesTable = Self.photoIssuesTable
        let keywordsTable = Self.photoKeywordsTable
        let summaryTable = Self.keywordSummaryTable
        let assetsTable = Self.photoAssetsTable
        let metadataTable = Self.syncMetadataTable

        try? databaseManager.write { db in
            try db.execute(sql: "DELETE FROM \(issuesTable)")
            try db.execute(sql: "DELETE FROM \(keywordsTable)")
            try db.execute(sql: "DELETE FROM \(summaryTable)")
            try db.execute(sql: "DELETE FROM \(assetsTable)")
            try db.execute(sql: "DELETE FROM \(metadataTable)")
        }
    }

    private static func secondsSince1970(from date: Date?) -> Int64? {
        guard let date else { return nil }
        return Int64(date.timeIntervalSince1970)
    }

    private static func date(fromSecondsSince1970 value: Int64?) -> Date? {
        guard let value else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(value))
    }
}
