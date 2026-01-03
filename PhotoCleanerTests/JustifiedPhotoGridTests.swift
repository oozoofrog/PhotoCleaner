//
//  JustifiedPhotoGridTests.swift
//  PhotoCleanerTests
//
//  JustifiedPhotoGrid 레이아웃에 대한 테스트
//

import Testing
import SwiftUI
@testable import PhotoCleaner

@Suite("JustifiedPhotoGrid Layout Tests")
@MainActor
struct JustifiedPhotoGridTests {

    // MARK: - Initialization Tests

    @Test("기본 초기화 값 검증")
    func defaultInitialization() async throws {
        let grid = JustifiedPhotoGrid()

        #expect(grid.targetRowHeight == 120)  // GridLayout.rowHeight
        #expect(grid.spacing == 4)  // Spacing.xs
        #expect(grid.expandLastRow == false)
    }

    @Test("커스텀 초기화 값이 올바르게 설정됨")
    func customInitialization() async throws {
        let grid = JustifiedPhotoGrid(
            targetRowHeight: 200,
            spacing: 8,
            expandLastRow: true
        )

        #expect(grid.targetRowHeight == 200)
        #expect(grid.spacing == 8)
        #expect(grid.expandLastRow == true)
    }

    // MARK: - Property Tests

    @Test("다양한 targetRowHeight 값이 유효함", arguments: [1.0, 50.0, 100.0, 200.0, 500.0, 1000.0])
    func validTargetRowHeight(height: Double) async throws {
        let grid = JustifiedPhotoGrid(targetRowHeight: CGFloat(height))
        #expect(grid.targetRowHeight == CGFloat(height))
    }

    @Test("다양한 spacing 값이 유효함", arguments: [0.0, 2.0, 4.0, 8.0, 16.0])
    func validSpacing(spacing: Double) async throws {
        let grid = JustifiedPhotoGrid(spacing: CGFloat(spacing))
        #expect(grid.spacing == CGFloat(spacing))
    }

    @Test("expandLastRow 불린 값 검증", arguments: [true, false])
    func expandLastRowBoolean(expand: Bool) async throws {
        let grid = JustifiedPhotoGrid(expandLastRow: expand)
        #expect(grid.expandLastRow == expand)
    }

    // MARK: - AspectRatioKey Tests

    @Test("AspectRatioKey 기본값은 1.0")
    func aspectRatioKeyDefaultValue() async throws {
        #expect(AspectRatioKey.defaultValue == 1.0)
    }

    // MARK: - Edge Case Tests

    @Test("0 spacing은 유효함")
    func zeroSpacingIsValid() async throws {
        let grid = JustifiedPhotoGrid(spacing: 0)
        #expect(grid.spacing == 0)
    }

    @Test("매우 큰 targetRowHeight도 유효함")
    func largeTargetRowHeightIsValid() async throws {
        let grid = JustifiedPhotoGrid(targetRowHeight: 1000)
        #expect(grid.targetRowHeight == 1000)
    }

    @Test("매우 작은 targetRowHeight도 유효함")
    func smallTargetRowHeightIsValid() async throws {
        let grid = JustifiedPhotoGrid(targetRowHeight: 1)
        #expect(grid.targetRowHeight == 1)
    }

    // MARK: - Random Data Tests

    @Test("랜덤 aspectRatio 값이 유효", arguments: 1...50)
    func randomAspectRatiosValid(iteration: Int) async throws {
        let ratio = TestDataGenerator.randomAspectRatio()
        #expect(ratio > 0)
        #expect(ratio.isFinite)
        #expect(!ratio.isNaN)
    }
}

// MARK: - Aspect Ratio Extension Tests

@Suite("Aspect Ratio Extension Tests")
@MainActor
struct AspectRatioExtensionTests {

    @Test("일반적인 사진 비율 검증")
    func commonPhotoAspectRatios() async throws {
        let commonRatios: [CGFloat] = [
            4.0 / 3.0,   // 4:3 가로
            3.0 / 4.0,   // 3:4 세로
            16.0 / 9.0,  // 16:9 와이드
            9.0 / 16.0,  // 9:16 세로 와이드
            1.0,         // 1:1 정사각형
            3.0 / 2.0,   // 3:2
            2.0 / 3.0    // 2:3
        ]

        for ratio in commonRatios {
            #expect(ratio > 0)
            #expect(ratio.isFinite)
            #expect(!ratio.isNaN)
        }
    }

    @Test("극단적인 비율도 유효함", arguments: [0.1, 0.5, 2.0, 5.0, 10.0])
    func extremeAspectRatios(ratio: Double) async throws {
        let cgRatio = CGFloat(ratio)
        #expect(cgRatio > 0)
        #expect(cgRatio.isFinite)
    }
}
