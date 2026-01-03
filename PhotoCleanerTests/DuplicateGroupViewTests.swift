//
//  DuplicateGroupViewTests.swift
//  PhotoCleanerTests
//
//  중복 그룹 UI 관련 테스트 (TDD)
//

import Testing
@testable import PhotoCleaner

// MARK: - DuplicateGroup Model Extensions Tests

@Suite("DuplicateGroup UI Extensions")
@MainActor
struct DuplicateGroupUITests {
    
    // MARK: - isOriginal 테스트
    
    @Test("isOriginal은 suggestedOriginalId와 일치할 때 true")
    func isOriginalReturnsTrueForSuggestedOriginal() {
        let group = DuplicateGroup(
            id: "test",
            assetIdentifiers: ["original", "dup1", "dup2"],
            suggestedOriginalId: "original",
            similarity: 1.0,
            potentialSavings: 2000
        )
        
        #expect(group.isOriginal("original") == true)
    }
    
    @Test("isOriginal은 중복 사진에 대해 false")
    func isOriginalReturnsFalseForDuplicate() {
        let group = DuplicateGroup(
            id: "test",
            assetIdentifiers: ["original", "dup1", "dup2"],
            suggestedOriginalId: "original",
            similarity: 1.0,
            potentialSavings: 2000
        )
        
        #expect(group.isOriginal("dup1") == false)
        #expect(group.isOriginal("dup2") == false)
    }
    
    // MARK: - isExactDuplicate 테스트
    
    @Test("similarity 1.0은 완전 동일")
    func similarityOneIsExactDuplicate() {
        let group = DuplicateGroup(
            id: "sha256:abc",
            assetIdentifiers: ["a", "b"],
            suggestedOriginalId: "a",
            similarity: 1.0,
            potentialSavings: 1000
        )
        
        #expect(group.isExactDuplicate == true)
    }
    
    @Test("similarity 0.95은 유사 사진")
    func similarityLessThanOneIsSimilar() {
        let group = DuplicateGroup(
            id: "similar:xyz",
            assetIdentifiers: ["a", "b"],
            suggestedOriginalId: "a",
            similarity: 0.95,
            potentialSavings: 1000
        )
        
        #expect(group.isExactDuplicate == false)
    }
    
    // MARK: - duplicateAssetIdentifiers 테스트
    
    @Test("duplicateAssetIdentifiers는 원본을 제외한 목록")
    func duplicateAssetIdentifiersExcludesOriginal() {
        let group = DuplicateGroup(
            id: "test",
            assetIdentifiers: ["original", "dup1", "dup2", "dup3"],
            suggestedOriginalId: "original",
            similarity: 1.0,
            potentialSavings: 3000
        )
        
        let duplicates = group.duplicateAssetIdentifiers
        
        #expect(duplicates.count == 3)
        #expect(!duplicates.contains("original"))
        #expect(duplicates.contains("dup1"))
        #expect(duplicates.contains("dup2"))
        #expect(duplicates.contains("dup3"))
    }
    
    @Test("원본만 있는 그룹에서 duplicateAssetIdentifiers는 빈 배열")
    func singleItemGroupHasNoDuplicates() {
        let group = DuplicateGroup(
            id: "test",
            assetIdentifiers: ["only"],
            suggestedOriginalId: "only",
            similarity: 1.0,
            potentialSavings: 0
        )
        
        #expect(group.duplicateAssetIdentifiers.isEmpty)
    }
    
    // MARK: - similarityLabel 테스트
    
    @Test("완전 동일 그룹의 라벨은 '완전 동일'")
    func exactDuplicateLabelIsCorrect() {
        let group = DuplicateGroup(
            id: "test",
            assetIdentifiers: ["a", "b"],
            suggestedOriginalId: "a",
            similarity: 1.0,
            potentialSavings: 1000
        )
        
        #expect(group.similarityLabel == "완전 동일")
    }
    
    @Test("유사 사진 그룹의 라벨은 퍼센트 표시")
    func similarPhotoLabelShowsPercentage() {
        let group = DuplicateGroup(
            id: "test",
            assetIdentifiers: ["a", "b"],
            suggestedOriginalId: "a",
            similarity: 0.95,
            potentialSavings: 1000
        )
        
        #expect(group.similarityLabel == "95% 유사")
    }
    
    @Test("87% 유사도는 올바르게 표시")
    func similarity87PercentShowsCorrectly() {
        let group = DuplicateGroup(
            id: "test",
            assetIdentifiers: ["a", "b"],
            suggestedOriginalId: "a",
            similarity: 0.87,
            potentialSavings: 1000
        )
        
        #expect(group.similarityLabel == "87% 유사")
    }
}

// MARK: - DuplicateGroup Sorting Tests

@Suite("DuplicateGroup Sorting")
@MainActor
struct DuplicateGroupSortingTests {
    
    @Test("그룹은 potentialSavings 내림차순 정렬 가능")
    func groupsSortByPotentialSavingsDescending() {
        let groups = [
            DuplicateGroup(id: "small", assetIdentifiers: ["a", "b"], suggestedOriginalId: "a", similarity: 1.0, potentialSavings: 100),
            DuplicateGroup(id: "large", assetIdentifiers: ["c", "d"], suggestedOriginalId: "c", similarity: 1.0, potentialSavings: 5000),
            DuplicateGroup(id: "medium", assetIdentifiers: ["e", "f"], suggestedOriginalId: "e", similarity: 1.0, potentialSavings: 1000)
        ]
        
        let sorted = groups.sorted { $0.potentialSavings > $1.potentialSavings }
        
        #expect(sorted[0].id == "large")
        #expect(sorted[1].id == "medium")
        #expect(sorted[2].id == "small")
    }
    
    @Test("그룹은 count 내림차순 정렬 가능")
    func groupsSortByCountDescending() {
        let groups = [
            DuplicateGroup(id: "two", assetIdentifiers: ["a", "b"], suggestedOriginalId: "a", similarity: 1.0, potentialSavings: 100),
            DuplicateGroup(id: "five", assetIdentifiers: ["c", "d", "e", "f", "g"], suggestedOriginalId: "c", similarity: 1.0, potentialSavings: 100),
            DuplicateGroup(id: "three", assetIdentifiers: ["h", "i", "j"], suggestedOriginalId: "h", similarity: 1.0, potentialSavings: 100)
        ]
        
        let sorted = groups.sorted { $0.count > $1.count }
        
        #expect(sorted[0].id == "five")
        #expect(sorted[1].id == "three")
        #expect(sorted[2].id == "two")
    }
}

@Suite("DuplicateGroup Deletion")
@MainActor
struct DuplicateGroupDeletionTests {
    
    @Test("duplicateAssetIdentifiers는 삭제 대상 목록")
    func duplicateAssetIdentifiersAreDeleteTargets() {
        let group = DuplicateGroup(
            id: "test",
            assetIdentifiers: ["keep", "delete1", "delete2"],
            suggestedOriginalId: "keep",
            similarity: 1.0,
            potentialSavings: 2000
        )
        
        let toDelete = group.duplicateAssetIdentifiers
        
        #expect(toDelete.count == 2)
        #expect(!toDelete.contains("keep"))
        #expect(toDelete.contains("delete1"))
        #expect(toDelete.contains("delete2"))
    }
    
    @Test("원본이 첫 번째가 아닌 경우에도 올바르게 필터링")
    func originalInMiddleIsFilteredCorrectly() {
        let group = DuplicateGroup(
            id: "test",
            assetIdentifiers: ["dup1", "original", "dup2"],
            suggestedOriginalId: "original",
            similarity: 1.0,
            potentialSavings: 2000
        )
        
        let toDelete = group.duplicateAssetIdentifiers
        
        #expect(toDelete.count == 2)
        #expect(!toDelete.contains("original"))
    }
}
