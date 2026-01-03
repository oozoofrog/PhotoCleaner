//
//  IssueMetadataTests.swift
//  PhotoCleanerTests
//
//  IssueMetadata에 대한 테스트
//

import Testing
@testable import PhotoCleaner

@Suite("IssueMetadata Tests")
@MainActor
struct IssueMetadataTests {

    // MARK: - Initialization Tests

    @Test("기본 초기화는 모든 값이 nil 또는 false")
    func defaultInitialization() async throws {
        let metadata = IssueMetadata()

        #expect(metadata.fileSize == nil)
        #expect(metadata.errorMessage == nil)
        #expect(metadata.duplicateGroupId == nil)
        #expect(metadata.canRecover == false)
    }

    @Test("커스텀 초기화 값이 올바르게 설정됨")
    func customInitialization() async throws {
        let metadata = IssueMetadata(
            fileSize: 1024 * 1024 * 10,  // 10MB
            errorMessage: "Network error",
            duplicateGroupId: "group-123",
            canRecover: true
        )

        #expect(metadata.fileSize == 10_485_760)
        #expect(metadata.errorMessage == "Network error")
        #expect(metadata.duplicateGroupId == "group-123")
        #expect(metadata.canRecover == true)
    }

    // MARK: - formattedFileSize Tests

    @Test("fileSize가 nil이면 formattedFileSize도 nil")
    func formattedFileSizeNilWhenFileSizeNil() async throws {
        let metadata = IssueMetadata(fileSize: nil)
        #expect(metadata.formattedFileSize == nil)
    }

    @Test("양수 fileSize는 non-nil formattedFileSize 반환")
    func formattedFileSizeNotNilForPositiveFileSize() async throws {
        let testSizes: [Int64] = [0, 1, 1024, 1024 * 1024, 1024 * 1024 * 1024]

        for size in testSizes {
            let metadata = IssueMetadata(fileSize: size)
            #expect(metadata.formattedFileSize != nil)
        }
    }

    @Test("formattedFileSize 형식 검증 - 기본 케이스")
    func formattedFileSizeFormat() async throws {
        // 1 KB
        let metadata1KB = IssueMetadata(fileSize: 1024)
        #expect(metadata1KB.formattedFileSize?.contains("KB") == true ||
                metadata1KB.formattedFileSize?.contains("bytes") == true)

        // 1 MB
        let metadata1MB = IssueMetadata(fileSize: 1024 * 1024)
        #expect(metadata1MB.formattedFileSize?.contains("MB") == true ||
                metadata1MB.formattedFileSize?.contains("KB") == true)

        // 1 GB
        let metadata1GB = IssueMetadata(fileSize: 1024 * 1024 * 1024)
        #expect(metadata1GB.formattedFileSize?.contains("GB") == true ||
                metadata1GB.formattedFileSize?.contains("MB") == true)
    }

    // MARK: - Random Data Tests

    @Test("랜덤 fileSize에 대해 formattedFileSize가 crash하지 않음", arguments: 1...100)
    func formattedFileSizeNeverCrashes(iteration: Int) async throws {
        let size = TestDataGenerator.randomPositiveFileSize()
        let metadata = IssueMetadata(fileSize: size)
        _ = metadata.formattedFileSize
        // 크래시 없이 완료되면 성공
    }

    @Test("양수 fileSize는 항상 non-nil formattedFileSize 반환", arguments: 1...100)
    func positiveFileSizeAlwaysFormats(iteration: Int) async throws {
        let size = TestDataGenerator.randomPositiveFileSize()
        let metadata = IssueMetadata(fileSize: size)
        #expect(metadata.formattedFileSize != nil)
    }

    @Test("IssueMetadata는 Hashable 일관성을 유지", arguments: 1...50)
    func metadataHashableConsistency(iteration: Int) async throws {
        let metadata = TestDataGenerator.randomMetadata()
        let hash1 = metadata.hashValue
        let hash2 = metadata.hashValue
        #expect(hash1 == hash2)
    }

    @Test("동일한 값의 IssueMetadata는 동등함")
    func metadataEquality() async throws {
        let testCases: [(Int64?, String?, Bool)] = [
            (nil, nil, false),
            (1024, nil, true),
            (nil, "error", false),
            (1024 * 1024, "test error", true)
        ]

        for (fileSize, errorMessage, canRecover) in testCases {
            let m1 = IssueMetadata(
                fileSize: fileSize,
                errorMessage: errorMessage,
                canRecover: canRecover
            )
            let m2 = IssueMetadata(
                fileSize: fileSize,
                errorMessage: errorMessage,
                canRecover: canRecover
            )
            #expect(m1 == m2)
        }
    }
}
