//
//  DuplicateLogicPropertyTests.swift
//  PhotoCleanerTests
//
//  Created by oozoofrog on 1/11/26.
//

import Testing
import Foundation
@testable import PhotoCleaner

@Suite("Duplicate Logic Property Tests")
@MainActor
struct DuplicateLogicPropertyTests {

    // MARK: - Properties: Bucket Key Determinism

    @Test("Bucket Key is deterministic (Same input -> Same output)", arguments: 1...100)
    func bucketKeyDeterminism(iteration: Int) {
        // Given
        let metadata = TestDataGenerator.randomAssetMetadata()
        let calendar = Calendar.current
        
        // When
        let key1 = DuplicateGroupingLogic.bucketKey(for: metadata, calendar: calendar)
        let key2 = DuplicateGroupingLogic.bucketKey(for: metadata, calendar: calendar)
        
        // Then
        #expect(key1 == key2)
    }
    
    // MARK: - Properties: Original Selection Stability

    @Test("Original selection is independent of input order", arguments: 1...100)
    func originalSelectionStability(iteration: Int) {
        // Given
        let count = Int.random(in: 2...20)
        var candidates: [AssetMetadata] = []
        for _ in 0..<count {
            candidates.append(TestDataGenerator.randomAssetMetadata())
        }
        
        // When
        let shuffledA = candidates.shuffled()
        let shuffledB = candidates.shuffled()
        
        let sortedA = DuplicateGroupingLogic.selectOriginalFirst(
            shuffledA,
            resolution: { $0.pixelWidth * $0.pixelHeight },
            byteCount: { $0.byteCount },
            creationDate: { $0.creationDate },
            stableId: { $0.assetId }
        )
        
        let sortedB = DuplicateGroupingLogic.selectOriginalFirst(
            shuffledB,
            resolution: { $0.pixelWidth * $0.pixelHeight },
            byteCount: { $0.byteCount },
            creationDate: { $0.creationDate },
            stableId: { $0.assetId }
        )
        
        // Then
        // The "Original" (first element) must be identical
        #expect(sortedA.first?.assetId == sortedB.first?.assetId)
        
        // The set of elements must be identical (just order changed for non-originals?)
        // Actually, our sorting logic is fully deterministic including stableId, so the entire LIST should be identical
        #expect(sortedA.map(\.assetId) == sortedB.map(\.assetId))
    }

    // MARK: - Properties: Union-Find Connectedness

    @Test("Union-Find path compression preserves connectivity", arguments: 1...100)
    func unionFindConnectivity(iteration: Int) {
        // Given
        let size = 20
        var uf = DuplicateGroupingLogic.UnionFind(count: size)
        
        // Create random connections
        let connections = (0..<size).map { _ in
            (Int.random(in: 0..<size), Int.random(in: 0..<size))
        }
        
        for (u, v) in connections {
            uf.union(u, v)
        }
        
        // When & Then
        // Check that known connections report same root
        for (u, v) in connections {
            #expect(uf.find(u) == uf.find(v))
        }
    }
    
    @Test("Union-Find transitivity (A~B, B~C -> A~C)", arguments: 1...50)
    func unionFindTransitivity(iteration: Int) {
        var uf = DuplicateGroupingLogic.UnionFind(count: 10)
        
        // A=0, B=1, C=2
        uf.union(0, 1)
        uf.union(1, 2)
        
        // A should be connected to C
        #expect(uf.find(0) == uf.find(2))
    }
}
