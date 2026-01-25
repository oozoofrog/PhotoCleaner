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

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // 아이콘과 개수
                HStack {
                    Image(systemName: issueType.iconName)
                        .font(.system(size: IconSize.lg))
                        .foregroundStyle(issueType.color)

                    Spacer()

                    if count > 0 {
                        Text("\(count)")
                            .font(Typography.mediumNumber)
                            .foregroundStyle(issueType.color)
                            .contentTransition(.numericText())
                            .scaleEffect(isAnimating ? 1.15 : 1.0)
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
            .background(AppColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .strokeBorder(
                        isAnimating ? issueType.color.opacity(0.3) : Color.clear,
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(.plain)
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
