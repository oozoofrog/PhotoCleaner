//
//  ScanStatus.swift
//  PhotoCleaner
//

enum ScanStatus: String, Codable, Sendable {
    case pending
    case scanned
    case failed
}
