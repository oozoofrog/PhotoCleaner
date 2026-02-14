//
//  DatabaseMigrations.swift
//  PhotoCleaner
//

import Foundation
import GRDB

enum DatabaseMigrations {
    static let currentSchemaVersion = 1
    static let syncMetadataKey = "photoLibraryToken"

    static let photoAssetsTable = "photo_assets"
    static let photoIssuesTable = "photo_issues"
    static let photoKeywordsTable = "photo_keywords"
    static let keywordSummaryTable = "keyword_summary"
    static let syncMetadataTable = "sync_metadata"

    static func registerMigrations(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v1_create_cache_schema") { db in
            try db.create(table: photoAssetsTable) { table in
                table.primaryKey(["local_identifier"], onConflict: .replace)
                table.column("local_identifier", .text).notNull()
                table.column("creation_date", .integer)
                table.column("pixel_width", .integer).notNull()
                table.column("pixel_height", .integer).notNull()
                table.column("media_subtypes", .integer).notNull()
                table.column("scan_status", .text).notNull()
                table.column("failure_reason", .text)
                table.column("last_scanned_at", .integer)
                table.column("resource_hash", .text)
                table.column("resource_byte_count", .integer)
                table.column("feature_print_data", .blob)
                table.column("feature_print_version", .text)
            }

            try db.create(index: "idx_photo_assets_scan_status", on: photoAssetsTable, columns: ["scan_status"])

            try db.create(table: photoIssuesTable) { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("asset_identifier", .text).notNull().references(photoAssetsTable, onDelete: .cascade)
                table.column("issue_type", .text).notNull()
                table.column("severity", .integer).notNull()
                table.column("detected_at", .integer).notNull()
                table.column("file_size", .integer)
                table.column("error_message", .text)
                table.column("duplicate_group_id", .text)
                table.column("can_recover", .boolean).notNull()
            }

            try db.create(index: "idx_photo_issues_asset", on: photoIssuesTable, columns: ["asset_identifier"])

            try db.create(table: photoKeywordsTable) { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("asset_identifier", .text).notNull().references(photoAssetsTable, onDelete: .cascade)
                table.column("keyword", .text).notNull()
                table.column("confidence", .double).notNull()
                table.column("language_code", .text).notNull().defaults(to: "")
                table.column("created_at", .integer).notNull()
                table.column("is_manual", .boolean).notNull().defaults(to: false)
            }

            try db.create(index: "idx_photo_keywords_asset", on: photoKeywordsTable, columns: ["asset_identifier"])
            try db.create(index: "idx_photo_keywords_keyword", on: photoKeywordsTable, columns: ["keyword"])

            try db.create(table: keywordSummaryTable) { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("keyword", .text).notNull()
                table.column("language_code", .text).notNull().defaults(to: "")
                table.column("asset_count", .integer).notNull().defaults(to: 0)
                table.column("updated_at", .integer).notNull().defaults(to: Date().timeIntervalSince1970)
            }

            try db.create(table: syncMetadataTable) { table in
                table.primaryKey(["key"], onConflict: .replace)
                table.column("key", .text).notNull()
                table.column("token_data", .blob)
                table.column("last_sync_at", .integer)
                table.column("schema_version", .integer).notNull()
            }

            try db.create(index: "idx_keyword_summary_keyword", on: keywordSummaryTable, columns: ["keyword", "language_code"], unique: true)
        }
    }
}
