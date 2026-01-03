//
//  PhotoIssueTests.swift
//  PhotoCleanerTests
//
//  IssueType 및 IssueSeverity 열거형에 대한 테스트
//

import Testing
@testable import PhotoCleaner

@Suite("PhotoIssue Model Tests")
@MainActor
struct PhotoIssueTests {

    // MARK: - IssueType Tests

    @Test("모든 IssueType은 non-empty displayName을 가짐")
    func issueTypeDisplayNameNotEmpty() async throws {
        for issueType in IssueType.allCases {
            #expect(!issueType.displayName.isEmpty)
        }
    }

    @Test("모든 IssueType은 유효한 SF Symbol iconName을 가짐")
    func issueTypeIconNameValid() async throws {
        for issueType in IssueType.allCases {
            #expect(!issueType.iconName.isEmpty)
            // SF Symbol 이름은 알파벳과 점만 포함
            #expect(issueType.iconName.allSatisfy { $0.isLetter || $0 == "." })
        }
    }

    @Test("모든 IssueType은 non-empty userDescription을 가짐")
    func issueTypeUserDescriptionNotEmpty() async throws {
        for issueType in IssueType.allCases {
            #expect(!issueType.userDescription.isEmpty)
        }
    }

    @Test("IssueType의 defaultSeverity는 올바른 값을 반환")
    func issueTypeDefaultSeverity() async throws {
        #expect(IssueType.downloadFailed.defaultSeverity == .warning)
        #expect(IssueType.corrupted.defaultSeverity == .critical)
        #expect(IssueType.screenshot.defaultSeverity == .info)
        #expect(IssueType.largeFile.defaultSeverity == .info)
        #expect(IssueType.duplicate.defaultSeverity == .info)
    }

    // MARK: - IssueSeverity Tests

    @Test("IssueSeverity의 순서: info < warning < critical")
    func issueSeverityOrdering() async throws {
        #expect(IssueSeverity.info < IssueSeverity.warning)
        #expect(IssueSeverity.warning < IssueSeverity.critical)
        #expect(IssueSeverity.info < IssueSeverity.critical)
    }

    @Test("IssueSeverity displayName은 non-empty")
    func issueSeverityDisplayNameNotEmpty() async throws {
        let severities: [IssueSeverity] = [.info, .warning, .critical]
        for severity in severities {
            #expect(!severity.displayName.isEmpty)
        }
    }

    // MARK: - Consistency Tests

    @Test("IssueType rawValue는 unique")
    func issueTypeRawValuesAreUnique() async throws {
        let rawValues = IssueType.allCases.map(\.rawValue)
        let uniqueRawValues = Set(rawValues)
        #expect(rawValues.count == uniqueRawValues.count)
    }

    @Test("IssueType id는 rawValue와 동일")
    func issueTypeIdEqualsRawValue() async throws {
        for issueType in IssueType.allCases {
            #expect(issueType.id == issueType.rawValue)
        }
    }

    @Test("IssueSeverity rawValue는 순서대로 증가")
    func issueSeverityRawValueIncreases() async throws {
        #expect(IssueSeverity.info.rawValue == 0)
        #expect(IssueSeverity.warning.rawValue == 1)
        #expect(IssueSeverity.critical.rawValue == 2)
    }

    @Test("IssueSeverity 비교 연산은 rawValue 비교와 일치")
    func issueSeverityComparisonMatchesRawValue() async throws {
        let severities: [IssueSeverity] = [.info, .warning, .critical]

        for a in severities {
            for b in severities {
                #expect((a < b) == (a.rawValue < b.rawValue))
            }
        }
    }

    // MARK: - Random Data Tests

    @Test("랜덤 IssueType은 항상 유효한 속성을 가짐", arguments: 1...100)
    func randomIssueTypeHasValidProperties(iteration: Int) async throws {
        let issueType = TestDataGenerator.randomIssueType()

        #expect(!issueType.displayName.isEmpty)
        #expect(!issueType.iconName.isEmpty)
        #expect(!issueType.userDescription.isEmpty)
        #expect(issueType.id == issueType.rawValue)
    }

    @Test("랜덤 IssueSeverity 비교는 일관성 유지", arguments: 1...100)
    func randomSeverityComparisonConsistent(iteration: Int) async throws {
        let a = TestDataGenerator.randomSeverity()
        let b = TestDataGenerator.randomSeverity()

        #expect((a < b) == (a.rawValue < b.rawValue))
    }
}
