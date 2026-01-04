//
//  DuplicateGroupingLogicTests.swift
//  PhotoCleanerTests
//
//  순수 로직 테스트 (PhotoKit 의존성 없음)
//

import Testing
@testable import PhotoCleaner
import Foundation

// MARK: - Bucket Key Tests

@Suite("DuplicateGroupingLogic - Bucket Key")
@MainActor
struct BucketKeyTests {
    
    @Test("같은 날, 비슷한 해상도/비율의 사진은 같은 버킷")
    func sameBucketForSimilarPhotos() {
        let calendar = Calendar.current
        let baseDate = calendar.date(from: DateComponents(year: 2025, month: 6, day: 15))!
        
        let meta1 = AssetMetadata(
            assetId: "a",
            pixelWidth: 4000,
            pixelHeight: 3000,
            creationDate: baseDate,
            byteCount: 1000
        )
        
        let meta2 = AssetMetadata(
            assetId: "b",
            pixelWidth: 4032,
            pixelHeight: 3024,
            creationDate: baseDate,
            byteCount: 1200
        )
        
        let key1 = DuplicateGroupingLogic.bucketKey(for: meta1, calendar: calendar)
        let key2 = DuplicateGroupingLogic.bucketKey(for: meta2, calendar: calendar)
        
        #expect(key1 == key2)
    }
    
    @Test("다른 주의 사진은 다른 버킷")
    func differentBucketForDifferentWeek() {
        let calendar = Calendar.current
        let date1 = calendar.date(from: DateComponents(year: 2025, month: 6, day: 1))!
        let date2 = calendar.date(from: DateComponents(year: 2025, month: 6, day: 15))!
        
        let meta1 = AssetMetadata(assetId: "a", pixelWidth: 4000, pixelHeight: 3000, creationDate: date1, byteCount: 1000)
        let meta2 = AssetMetadata(assetId: "b", pixelWidth: 4000, pixelHeight: 3000, creationDate: date2, byteCount: 1000)
        
        let key1 = DuplicateGroupingLogic.bucketKey(for: meta1, calendar: calendar)
        let key2 = DuplicateGroupingLogic.bucketKey(for: meta2, calendar: calendar)
        
        #expect(key1 != key2)
    }
    
    @Test("다른 해상도 등급은 다른 버킷")
    func differentBucketForDifferentResolution() {
        let date = Date()
        
        // low: < 4MP
        let lowRes = AssetMetadata(assetId: "a", pixelWidth: 1000, pixelHeight: 1000, creationDate: date, byteCount: 100)
        // medium: 4-12MP
        let medRes = AssetMetadata(assetId: "b", pixelWidth: 3000, pixelHeight: 2000, creationDate: date, byteCount: 100)
        // high: > 12MP
        let highRes = AssetMetadata(assetId: "c", pixelWidth: 5000, pixelHeight: 4000, creationDate: date, byteCount: 100)
        
        let calendar = Calendar.current
        let keyLow = DuplicateGroupingLogic.bucketKey(for: lowRes, calendar: calendar)
        let keyMed = DuplicateGroupingLogic.bucketKey(for: medRes, calendar: calendar)
        let keyHigh = DuplicateGroupingLogic.bucketKey(for: highRes, calendar: calendar)
        
        #expect(keyLow != keyMed)
        #expect(keyMed != keyHigh)
        #expect(keyLow != keyHigh)
    }
    
    @Test("날짜 없는 사진은 unknown 버킷")
    func unknownBucketForNilDate() {
        let meta = AssetMetadata(assetId: "a", pixelWidth: 4000, pixelHeight: 3000, creationDate: nil, byteCount: 1000)
        let key = DuplicateGroupingLogic.bucketKey(for: meta, calendar: .current)
        
        #expect(key.contains("unknown"))
    }
}

// MARK: - Original Selection Tests

@Suite("DuplicateGroupingLogic - Original Selection")
@MainActor
struct OriginalSelectionTests {
    
    @Test("해상도가 높은 사진이 원본으로 선택됨")
    func highestResolutionIsOriginal() {
        let candidates = [
            AssetMetadata(assetId: "low", pixelWidth: 1000, pixelHeight: 1000, creationDate: nil, byteCount: 100),
            AssetMetadata(assetId: "high", pixelWidth: 4000, pixelHeight: 3000, creationDate: nil, byteCount: 100),
            AssetMetadata(assetId: "mid", pixelWidth: 2000, pixelHeight: 1500, creationDate: nil, byteCount: 100)
        ]
        
        let sorted = DuplicateGroupingLogic.selectOriginalFirst(
            candidates,
            resolution: { $0.pixelWidth * $0.pixelHeight },
            byteCount: { $0.byteCount },
            creationDate: { $0.creationDate },
            stableId: { $0.assetId }
        )
        
        #expect(sorted.first?.assetId == "high")
    }
    
    @Test("해상도 동일 시 파일 크기가 큰 것이 원본")
    func largerFileSizeWhenSameResolution() {
        let candidates = [
            AssetMetadata(assetId: "small", pixelWidth: 4000, pixelHeight: 3000, creationDate: nil, byteCount: 100),
            AssetMetadata(assetId: "large", pixelWidth: 4000, pixelHeight: 3000, creationDate: nil, byteCount: 500)
        ]
        
        let sorted = DuplicateGroupingLogic.selectOriginalFirst(
            candidates,
            resolution: { $0.pixelWidth * $0.pixelHeight },
            byteCount: { $0.byteCount },
            creationDate: { $0.creationDate },
            stableId: { $0.assetId }
        )
        
        #expect(sorted.first?.assetId == "large")
    }
    
    @Test("해상도, 크기 동일 시 오래된 것이 원본")
    func olderDateWhenSameResolutionAndSize() {
        let older = Date(timeIntervalSince1970: 1000)
        let newer = Date(timeIntervalSince1970: 2000)
        
        let candidates = [
            AssetMetadata(assetId: "newer", pixelWidth: 4000, pixelHeight: 3000, creationDate: newer, byteCount: 100),
            AssetMetadata(assetId: "older", pixelWidth: 4000, pixelHeight: 3000, creationDate: older, byteCount: 100)
        ]
        
        let sorted = DuplicateGroupingLogic.selectOriginalFirst(
            candidates,
            resolution: { $0.pixelWidth * $0.pixelHeight },
            byteCount: { $0.byteCount },
            creationDate: { $0.creationDate },
            stableId: { $0.assetId }
        )
        
        #expect(sorted.first?.assetId == "older")
    }
    
    @Test("모두 동일 시 ID 알파벳 순")
    func alphabeticalWhenAllSame() {
        let date = Date()
        
        let candidates = [
            AssetMetadata(assetId: "c", pixelWidth: 4000, pixelHeight: 3000, creationDate: date, byteCount: 100),
            AssetMetadata(assetId: "a", pixelWidth: 4000, pixelHeight: 3000, creationDate: date, byteCount: 100),
            AssetMetadata(assetId: "b", pixelWidth: 4000, pixelHeight: 3000, creationDate: date, byteCount: 100)
        ]
        
        let sorted = DuplicateGroupingLogic.selectOriginalFirst(
            candidates,
            resolution: { $0.pixelWidth * $0.pixelHeight },
            byteCount: { $0.byteCount },
            creationDate: { $0.creationDate },
            stableId: { $0.assetId }
        )
        
        #expect(sorted.first?.assetId == "a")
    }
}

// MARK: - Union-Find Tests

@Suite("DuplicateGroupingLogic - UnionFind")
@MainActor
struct UnionFindTests {
    
    @Test("초기 상태에서 각 노드는 자신이 부모")
    func initialStateEachNodeIsSelfParent() {
        let uf = DuplicateGroupingLogic.UnionFind(count: 5)
        
        for i in 0..<5 {
            #expect(uf.parent[i] == i)
        }
    }
    
    @Test("union 후 find는 같은 루트 반환")
    func unionedNodesSameRoot() {
        var uf = DuplicateGroupingLogic.UnionFind(count: 5)
        uf.union(0, 1)
        uf.union(1, 2)
        
        #expect(uf.find(0) == uf.find(1))
        #expect(uf.find(1) == uf.find(2))
        #expect(uf.find(0) == uf.find(2))
    }
    
    @Test("서로 다른 그룹은 다른 루트")
    func separateGroupsDifferentRoots() {
        var uf = DuplicateGroupingLogic.UnionFind(count: 5)
        uf.union(0, 1)
        uf.union(3, 4)
        
        #expect(uf.find(0) == uf.find(1))
        #expect(uf.find(3) == uf.find(4))
        #expect(uf.find(0) != uf.find(3))
        #expect(uf.find(2) != uf.find(0)) // 2는 독립
    }
    
    @Test("같은 쌍을 여러 번 union해도 안전")
    func multipleUnionsSafe() {
        var uf = DuplicateGroupingLogic.UnionFind(count: 3)
        uf.union(0, 1)
        uf.union(0, 1)
        uf.union(1, 0)
        
        #expect(uf.find(0) == uf.find(1))
    }
}
