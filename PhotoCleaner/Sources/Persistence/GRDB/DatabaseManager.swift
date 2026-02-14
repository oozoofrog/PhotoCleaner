//
//  DatabaseManager.swift
//  PhotoCleaner
//

import Foundation
import GRDB

final class DatabaseManager {
    private let queue: DatabaseQueue
    let databasePath: String

    init(inMemory: Bool = false) throws {
        if inMemory {
            databasePath = ":memory:"
        } else {
            databasePath = try Self.defaultDatabasePath().path
        }

        queue = try DatabaseQueue(path: databasePath)
        try Self.migrate(queue)
    }

    static func makeDefault() throws -> DatabaseManager {
        try DatabaseManager()
    }

    static func makeInMemory() throws -> DatabaseManager {
        try DatabaseManager(inMemory: true)
    }

    func read<T>(_ body: (Database) throws -> T) throws -> T {
        try queue.read(body)
    }

    func write<T>(_ body: (Database) throws -> T) throws -> T {
        try queue.write(body)
    }

    private static func migrate(_ queue: DatabaseQueue) throws {
        var migrator = DatabaseMigrator()
        migrator.eraseDatabaseOnSchemaChange = true
        DatabaseMigrations.registerMigrations(&migrator)
        try migrator.migrate(queue)
    }

    private static func defaultDatabasePath() throws -> URL {
        let fm = FileManager.default
        let supportDirectory = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let baseDirectory = supportDirectory.appendingPathComponent("PhotoCleaner", isDirectory: true)
        if !fm.fileExists(atPath: baseDirectory.path) {
            try fm.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        }

        return baseDirectory.appendingPathComponent("photocleaner.sqlite")
    }
}
