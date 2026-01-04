//
//  DuplicateGroupingLogic.swift
//  PhotoCleaner
//

import Foundation

struct AssetMetadata: Sendable {
    let assetId: String
    let pixelWidth: Int
    let pixelHeight: Int
    let creationDate: Date?
    let byteCount: Int64
}

enum DuplicateGroupingLogic {
    
    nonisolated static func bucketKey(for metadata: AssetMetadata, calendar: Calendar = .current) -> String {
        let dateKey: String
        if let date = metadata.creationDate {
            let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 0
            let year = calendar.component(.year, from: date)
            let weekBucket = dayOfYear / 7
            dateKey = "\(year)-w\(weekBucket)"
        } else {
            dateKey = "unknown"
        }
        
        let aspectRatio = metadata.pixelHeight > 0
            ? Double(metadata.pixelWidth) / Double(metadata.pixelHeight)
            : 1.0
        let aspectBucket = Int(aspectRatio * 5) / 5
        
        let megapixels = (metadata.pixelWidth * metadata.pixelHeight) / 1_000_000
        let resolutionBucket: String =
            megapixels < 4 ? "low" : (megapixels < 12 ? "medium" : "high")
        
        return "\(dateKey)_\(aspectBucket)_\(resolutionBucket)"
    }
    
    nonisolated static func selectOriginalFirst<T: Sendable>(
        _ candidates: [T],
        resolution: (T) -> Int,
        byteCount: (T) -> Int64,
        creationDate: (T) -> Date?,
        stableId: (T) -> String
    ) -> [T] {
        candidates.sorted { lhs, rhs in
            if resolution(lhs) != resolution(rhs) { return resolution(lhs) > resolution(rhs) }
            if byteCount(lhs) != byteCount(rhs) { return byteCount(lhs) > byteCount(rhs) }
            let lhsDate = creationDate(lhs) ?? .distantFuture
            let rhsDate = creationDate(rhs) ?? .distantFuture
            if lhsDate != rhsDate { return lhsDate < rhsDate }
            return stableId(lhs) < stableId(rhs)
        }
    }
    
    struct UnionFind: Sendable {
        private(set) var parent: [Int]
        private(set) var rank: [Int]
        
        init(count: Int) {
            self.parent = Array(0..<count)
            self.rank = Array(repeating: 0, count: count)
        }
        
        mutating func find(_ x: Int) -> Int {
            if parent[x] != x { parent[x] = find(parent[x]) }
            return parent[x]
        }
        
        mutating func union(_ x: Int, _ y: Int) {
            let px = find(x)
            let py = find(y)
            guard px != py else { return }
            if rank[px] < rank[py] { parent[px] = py }
            else if rank[px] > rank[py] { parent[py] = px }
            else { parent[py] = px; rank[px] += 1 }
        }
    }
}
