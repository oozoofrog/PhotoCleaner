//
//  DuplicateCard.swift
//  PhotoCleaner
//
//  중복 사진 카드 컴포넌트
//

import SwiftUI

struct DuplicateCard: View {
    let groupCount: Int
    let duplicateCount: Int
    let potentialSavings: String
    var isUpdating: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        Image(systemName: "square.on.square")
                            .font(.system(size: IconSize.lg))
                            .foregroundStyle(AppColor.primary)

                        HStack(spacing: Spacing.xs) {
                            Text("중복 그룹 ")
                                .font(Typography.headline)
                                .foregroundStyle(AppColor.textPrimary)
                            Text("\(groupCount)")
                                .font(Typography.headline)
                                .foregroundStyle(AppColor.textPrimary)
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.3), value: groupCount)
                            Text("개")
                                .font(Typography.headline)
                                .foregroundStyle(AppColor.textPrimary)
                            if isUpdating {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                        }
                    }

                    HStack(spacing: 0) {
                        Text("\(duplicateCount)")
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3), value: duplicateCount)
                        Text("장 정리 시 \(potentialSavings) 확보")
                    }
                    .font(Typography.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
                }

                Spacer()

                if !isUpdating {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(AppColor.textTertiary)
                }
            }
            .padding(Spacing.md)
            .background(AppColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
        }
        .buttonStyle(.plain)
    }
}
