//
//  TestHelpers.swift
//  PhotoCleanerTests
//
//  테스트 헬퍼 - 랜덤 데이터 생성기
//

import Foundation
@testable import PhotoCleaner

// MARK: - Random Data Generators

/// 테스트용 랜덤 데이터 생성기
enum TestDataGenerator {

    /// 랜덤 IssueType 생성
    static func randomIssueType() -> IssueType {
        IssueType.allCases.randomElement()!
    }

    /// 랜덤 IssueSeverity 생성
    static func randomSeverity() -> IssueSeverity {
        [IssueSeverity.info, .warning, .critical].randomElement()!
    }

    /// 랜덤 IssueMetadata 생성
    static func randomMetadata() -> IssueMetadata {
        IssueMetadata(
            fileSize: Bool.random() ? Int64.random(in: 0...Int64.max) : nil,
            errorMessage: Bool.random() ? UUID().uuidString : nil,
            duplicateGroupId: Bool.random() ? UUID().uuidString : nil,
            canRecover: Bool.random()
        )
    }

    /// 랜덤 양수 파일 크기
    static func randomPositiveFileSize() -> Int64 {
        Int64.random(in: 0...Int64.max)
    }

    /// 랜덤 CGFloat (0~100 범위)
    static func randomAspectRatio() -> CGFloat {
        CGFloat.random(in: 0.1...10.0)
    }
}
