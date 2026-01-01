//
//  DesignTokens.swift
//  PhotoCleaner
//
//  PhotoCleaner 디자인 시스템의 핵심 토큰 정의
//  모든 UI 컴포넌트는 이 토큰을 사용하여 일관성을 유지합니다.
//

import SwiftUI

// MARK: - Spacing Tokens

/// 8pt 기반 간격 시스템
/// 모든 간격은 이 토큰을 사용하여 일관성을 유지합니다.
public enum Spacing {
    /// 4pt - 밀접한 요소 간격 (아이콘과 텍스트, 인라인 요소)
    public static let xs: CGFloat = 4

    /// 8pt - 관련 요소 간격 (리스트 항목 내부, 버튼 내부 패딩)
    public static let sm: CGFloat = 8

    /// 16pt - 섹션 내 요소 간격 (카드 내부 패딩, 컴포넌트 간)
    public static let md: CGFloat = 16

    /// 24pt - 섹션 간 간격 (섹션 구분, 그룹 간)
    public static let lg: CGFloat = 24

    /// 32pt - 주요 영역 간 간격 (화면 주요 섹션)
    public static let xl: CGFloat = 32

    /// 48pt - 화면 주요 구분 (헤더와 콘텐츠)
    public static let xxl: CGFloat = 48
}

// MARK: - Corner Radius Tokens

/// 모서리 둥글기 토큰
public enum CornerRadius {
    /// 4pt - 작은 요소 (태그, 뱃지)
    public static let xs: CGFloat = 4

    /// 8pt - 중소형 요소 (버튼, 입력 필드)
    public static let sm: CGFloat = 8

    /// 12pt - 중형 요소 (카드)
    public static let md: CGFloat = 12

    /// 16pt - 대형 요소 (모달, 시트)
    public static let lg: CGFloat = 16

    /// 20pt - 초대형 요소 (전체 화면 카드)
    public static let xl: CGFloat = 20

    /// 원형
    public static let full: CGFloat = .infinity
}

// MARK: - Icon Size Tokens

/// 아이콘 크기 토큰
public enum IconSize {
    /// 16pt - 인라인 아이콘 (텍스트 옆)
    public static let sm: CGFloat = 16

    /// 20pt - 기본 아이콘 (리스트, 버튼)
    public static let md: CGFloat = 20

    /// 24pt - 강조 아이콘 (탭바, 네비게이션)
    public static let lg: CGFloat = 24

    /// 32pt - 대형 아이콘 (빈 상태)
    public static let xl: CGFloat = 32

    /// 48pt - 초대형 아이콘 (온보딩, 강조)
    public static let xxl: CGFloat = 48

    /// 64pt - 히어로 아이콘 (빈 상태 중앙)
    public static let hero: CGFloat = 64
}

// MARK: - Touch Target

/// 터치 타겟 크기 토큰
/// Apple HIG 권장 최소 크기: 44pt
public enum TouchTarget {
    /// 44pt - 최소 터치 타겟 크기
    public static let minimum: CGFloat = 44

    /// 48pt - 권장 터치 타겟 크기
    public static let recommended: CGFloat = 48

    /// 56pt - 대형 터치 타겟 (FAB 등)
    public static let large: CGFloat = 56
}

// MARK: - Animation Tokens

/// 애니메이션 지속 시간 토큰
public enum AnimationDuration {
    /// 0.15초 - 마이크로 인터랙션 (체크, 탭 피드백)
    public static let micro: Double = 0.15

    /// 0.25초 - 빠른 전환 (토글, 펼치기)
    public static let fast: Double = 0.25

    /// 0.35초 - 표준 전환 (화면 전환, 모달)
    public static let standard: Double = 0.35

    /// 0.5초 - 느린 전환 (강조 애니메이션)
    public static let slow: Double = 0.5
}

// MARK: - Opacity Tokens

/// 불투명도 토큰
public enum Opacity {
    /// 0.0 - 완전 투명
    public static let transparent: Double = 0.0

    /// 0.1 - 매우 약한 (오버레이 힌트)
    public static let faint: Double = 0.1

    /// 0.3 - 비활성 상태
    public static let disabled: Double = 0.3

    /// 0.5 - 반투명 (오버레이)
    public static let half: Double = 0.5

    /// 0.7 - 강한 오버레이
    public static let strong: Double = 0.7

    /// 1.0 - 완전 불투명
    public static let opaque: Double = 1.0
}

// MARK: - Shadow Tokens

/// 그림자 스타일 토큰
public struct ShadowStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    /// 미세한 그림자 (카드)
    public static let subtle = ShadowStyle(
        color: Color.black.opacity(0.08),
        radius: 8,
        x: 0,
        y: 2
    )

    /// 중간 그림자 (플로팅 요소)
    public static let medium = ShadowStyle(
        color: Color.black.opacity(0.12),
        radius: 16,
        x: 0,
        y: 4
    )

    /// 강한 그림자 (모달)
    public static let strong = ShadowStyle(
        color: Color.black.opacity(0.2),
        radius: 24,
        x: 0,
        y: 8
    )
}

// MARK: - Color Tokens

/// 앱 색상 토큰
/// 시맨틱 컬러를 사용하여 라이트/다크 모드 자동 대응
public enum AppColor {

    // MARK: Primary Colors

    /// 주요 액션, 선택 상태, 링크
    public static let primary = Color.accentColor

    /// 주요 액션 버튼 배경
    public static let primaryFill = Color.accentColor

    /// 주요 액션 버튼 텍스트
    public static let primaryText = Color.white

    // MARK: Secondary Colors

    /// 보조 액션, 덜 중요한 정보
    public static let secondary = Color(.secondaryLabel)

    /// 보조 버튼 배경
    public static let secondaryFill = Color(.systemGray5)

    /// 보조 버튼 텍스트
    public static let secondaryText = Color(.label)

    // MARK: Destructive Colors

    /// 삭제, 경고, 오류
    public static let destructive = Color.red

    /// 삭제 버튼 배경
    public static let destructiveFill = Color.red

    /// 삭제 버튼 텍스트
    public static let destructiveText = Color.white

    // MARK: Success Colors

    /// 완료, 정상 상태, 성공
    public static let success = Color.green

    /// 성공 배경
    public static let successFill = Color.green.opacity(0.15)

    /// 성공 텍스트
    public static let successText = Color.green

    // MARK: Warning Colors

    /// 주의 필요, 경고
    public static let warning = Color.orange

    /// 경고 배경
    public static let warningFill = Color.orange.opacity(0.15)

    /// 경고 텍스트
    public static let warningText = Color.orange

    // MARK: Text Colors

    /// 기본 텍스트 (제목, 본문)
    public static let textPrimary = Color(.label)

    /// 보조 텍스트 (설명, 부제목)
    public static let textSecondary = Color(.secondaryLabel)

    /// 3차 텍스트 (메타 정보, 타임스탬프)
    public static let textTertiary = Color(.tertiaryLabel)

    /// 플레이스홀더 텍스트
    public static let textPlaceholder = Color(.placeholderText)

    // MARK: Background Colors

    /// 기본 배경 (화면 전체)
    public static let backgroundPrimary = Color(.systemBackground)

    /// 2차 배경 (카드, 그룹)
    public static let backgroundSecondary = Color(.secondarySystemBackground)

    /// 3차 배경 (중첩 요소)
    public static let backgroundTertiary = Color(.tertiarySystemBackground)

    /// 그룹 배경 (설정 화면 등)
    public static let backgroundGrouped = Color(.systemGroupedBackground)

    /// 그룹 내 배경
    public static let backgroundGroupedSecondary = Color(.secondarySystemGroupedBackground)

    // MARK: Border & Separator Colors

    /// 구분선
    public static let separator = Color(.separator)

    /// 불투명 구분선
    public static let separatorOpaque = Color(.opaqueSeparator)

    /// 테두리
    public static let border = Color(.systemGray4)

    // MARK: Fill Colors

    /// 기본 채우기
    public static let fill = Color(.systemFill)

    /// 2차 채우기
    public static let fillSecondary = Color(.secondarySystemFill)

    /// 3차 채우기
    public static let fillTertiary = Color(.tertiarySystemFill)
}

// MARK: - Typography Tokens

/// 타이포그래피 토큰
/// Dynamic Type을 지원하는 시스템 폰트 스타일
public enum Typography {

    // MARK: Display Styles (큰 제목)

    /// 초대형 제목 - 화면 메인 타이틀
    public static let largeTitle = Font.largeTitle.weight(.bold)

    /// 대형 제목 - 섹션 헤더
    public static let title = Font.title.weight(.bold)

    /// 중형 제목 - 서브섹션
    public static let title2 = Font.title2.weight(.semibold)

    /// 소형 제목 - 카드 제목
    public static let title3 = Font.title3.weight(.semibold)

    // MARK: Body Styles (본문)

    /// 강조 본문 - 중요 정보
    public static let headline = Font.headline

    /// 기본 본문 - 설명 텍스트
    public static let body = Font.body

    /// 콜아웃 - 강조 설명
    public static let callout = Font.callout

    /// 서브헤드라인 - 부제목
    public static let subheadline = Font.subheadline

    // MARK: Supporting Styles (보조)

    /// 각주 - 보조 정보
    public static let footnote = Font.footnote

    /// 캡션 - 메타 정보
    public static let caption = Font.caption

    /// 캡션2 - 최소 텍스트
    public static let caption2 = Font.caption2

    // MARK: Numeric Styles (숫자)

    /// 대형 숫자 - 통계 강조
    public static let largeNumber = Font.system(size: 34, weight: .bold, design: .rounded)

    /// 중형 숫자 - 카운트
    public static let mediumNumber = Font.system(size: 24, weight: .semibold, design: .rounded)

    /// 소형 숫자 - 뱃지
    public static let smallNumber = Font.system(size: 15, weight: .semibold, design: .rounded)
}

// MARK: - View Extensions

public extension View {
    /// 미세한 그림자 적용
    func subtleShadow() -> some View {
        self.shadow(
            color: ShadowStyle.subtle.color,
            radius: ShadowStyle.subtle.radius,
            x: ShadowStyle.subtle.x,
            y: ShadowStyle.subtle.y
        )
    }

    /// 중간 그림자 적용
    func mediumShadow() -> some View {
        self.shadow(
            color: ShadowStyle.medium.color,
            radius: ShadowStyle.medium.radius,
            x: ShadowStyle.medium.x,
            y: ShadowStyle.medium.y
        )
    }

    /// 강한 그림자 적용
    func strongShadow() -> some View {
        self.shadow(
            color: ShadowStyle.strong.color,
            radius: ShadowStyle.strong.radius,
            x: ShadowStyle.strong.x,
            y: ShadowStyle.strong.y
        )
    }

    /// 카드 스타일 적용
    func cardStyle() -> some View {
        self
            .padding(Spacing.md)
            .background(AppColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .subtleShadow()
    }

    /// 최소 터치 타겟 확보
    func ensureMinimumTouchTarget() -> some View {
        self.frame(minWidth: TouchTarget.minimum, minHeight: TouchTarget.minimum)
    }
}

// MARK: - Button Styles

/// 기본 버튼 스타일
public struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.headline)
            .foregroundStyle(AppColor.primaryText)
            .frame(maxWidth: .infinity)
            .frame(height: TouchTarget.minimum)
            .background(
                isEnabled
                    ? AppColor.primaryFill
                    : AppColor.primaryFill.opacity(Opacity.disabled)
            )
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: AnimationDuration.micro), value: configuration.isPressed)
    }
}

/// 보조 버튼 스타일
public struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.headline)
            .foregroundStyle(isEnabled ? AppColor.primary : AppColor.primary.opacity(Opacity.disabled))
            .frame(maxWidth: .infinity)
            .frame(height: TouchTarget.minimum)
            .background(AppColor.secondaryFill)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.sm)
                    .strokeBorder(AppColor.primary.opacity(isEnabled ? 1.0 : Opacity.disabled), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: AnimationDuration.micro), value: configuration.isPressed)
    }
}

/// 삭제 버튼 스타일
public struct DestructiveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.headline)
            .foregroundStyle(AppColor.destructiveText)
            .frame(maxWidth: .infinity)
            .frame(height: TouchTarget.minimum)
            .background(
                isEnabled
                    ? AppColor.destructiveFill
                    : AppColor.destructiveFill.opacity(Opacity.disabled)
            )
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: AnimationDuration.micro), value: configuration.isPressed)
    }
}

/// 고스트 버튼 스타일 (최소 강조)
public struct GhostButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.subheadline)
            .foregroundStyle(isEnabled ? AppColor.primary : AppColor.primary.opacity(Opacity.disabled))
            .frame(height: TouchTarget.minimum)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: AnimationDuration.micro), value: configuration.isPressed)
    }
}

// MARK: - Button Style Extensions

public extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

public extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

public extension ButtonStyle where Self == DestructiveButtonStyle {
    static var destructive: DestructiveButtonStyle { DestructiveButtonStyle() }
}

public extension ButtonStyle where Self == GhostButtonStyle {
    static var ghost: GhostButtonStyle { GhostButtonStyle() }
}

// MARK: - Preview

#if DEBUG
#Preview("Design Tokens") {
    ScrollView {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            // Colors
            Section {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Primary")
                        .foregroundStyle(AppColor.primary)
                    Text("Secondary")
                        .foregroundStyle(AppColor.secondary)
                    Text("Destructive")
                        .foregroundStyle(AppColor.destructive)
                    Text("Success")
                        .foregroundStyle(AppColor.success)
                    Text("Warning")
                        .foregroundStyle(AppColor.warning)
                }
            } header: {
                Text("Colors")
                    .font(Typography.title2)
            }

            Divider()

            // Typography
            Section {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Large Title")
                        .font(Typography.largeTitle)
                    Text("Title")
                        .font(Typography.title)
                    Text("Headline")
                        .font(Typography.headline)
                    Text("Body")
                        .font(Typography.body)
                    Text("Caption")
                        .font(Typography.caption)
                    Text("127")
                        .font(Typography.largeNumber)
                }
            } header: {
                Text("Typography")
                    .font(Typography.title2)
            }

            Divider()

            // Buttons
            Section {
                VStack(spacing: Spacing.md) {
                    Button("Primary Button") {}
                        .buttonStyle(.primary)

                    Button("Secondary Button") {}
                        .buttonStyle(.secondary)

                    Button("Destructive Button") {}
                        .buttonStyle(.destructive)

                    Button("Ghost Button") {}
                        .buttonStyle(.ghost)
                }
            } header: {
                Text("Buttons")
                    .font(Typography.title2)
            }

            Divider()

            // Cards
            Section {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Card Title")
                        .font(Typography.headline)
                    Text("This is a card with the standard card style applied.")
                        .font(Typography.body)
                        .foregroundStyle(AppColor.textSecondary)
                }
                .cardStyle()
            } header: {
                Text("Card Style")
                    .font(Typography.title2)
            }

            Divider()

            // Semantic Colors
            Section {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Label("경고", systemImage: "exclamationmark.icloud")
                        .foregroundStyle(AppColor.warning)
                    Label("오류", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(AppColor.destructive)
                    Label("정보", systemImage: "info.circle")
                        .foregroundStyle(AppColor.secondary)
                    Label("성공", systemImage: "checkmark.circle")
                        .foregroundStyle(AppColor.success)
                }
            } header: {
                Text("Semantic Colors")
                    .font(Typography.title2)
            }
        }
        .padding(Spacing.md)
    }
    .background(AppColor.backgroundPrimary)
}
#endif
