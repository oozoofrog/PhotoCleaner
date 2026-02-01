//
//  IssueCard.swift
//  PhotoCleaner
//
//  이슈 타입별 카드 컴포넌트
//

import SwiftUI

struct IssueCard: View {
    let issueType: IssueType
    let count: Int
    var isUpdating: Bool = false
    let onTap: () -> Void

    @State private var isAnimating = false
    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // 아이콘과 개수
                HStack {
                    Image(systemName: issueType.iconName)
                        .font(.system(size: IconSize.lg))
                        .foregroundStyle(issueType.color)
                        .shadow(color: count > 0 ? issueType.color.opacity(0.4) : .clear, radius: 8)

                    Spacer()

                    if count > 0 {
                        Text("\(count)")
                            .font(Typography.mediumNumber)
                            .foregroundStyle(issueType.color)
                            .contentTransition(.numericText())
                            .scaleEffect(isAnimating ? 1.15 : 1.0)
                            .shadow(color: issueType.color.opacity(0.3), radius: 4)
                            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isAnimating)
                    }
                }

                // 이름
                Text(issueType.displayName)
                    .font(Typography.subheadline)
                    .foregroundStyle(AppColor.textPrimary)

                // 상태
                Group {
                    if isUpdating {
                        HStack(spacing: Spacing.xs) {
                            Text("\(count)장 발견")
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    } else {
                        Text(count > 0 ? "\(count)장 발견" : "문제 없음")
                    }
                }
                .font(Typography.caption)
                .foregroundStyle(AppColor.textSecondary)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.lg)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                isPressed ? AppColor.accent.opacity(0.6) : (isAnimating ? issueType.color.opacity(0.3) : Color.white.opacity(0.1)),
                                isPressed ? AppColor.accent.opacity(0.3) : (isAnimating ? issueType.color.opacity(0.15) : Color.clear)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isPressed ? 2 : 1.5
                    )
            )
            .shadow(color: isPressed ? AppColor.accent.opacity(0.3) : .clear, radius: 12)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isPressed)
        }
        .buttonStyle(PressableButtonStyle(isPressed: $isPressed))
        .onChange(of: count) { oldValue, newValue in
            // 카운트 증가 시 애니메이션
            if newValue > oldValue && isUpdating {
                withAnimation {
                    isAnimating = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    withAnimation {
                        isAnimating = false
                    }
                }
            }
        }
    }
}

// MARK: - Pressable Button Style
private struct PressableButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
            }
    }
}
