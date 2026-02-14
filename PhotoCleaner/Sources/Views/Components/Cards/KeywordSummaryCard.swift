//
//  KeywordSummaryCard.swift
//  PhotoCleaner
//

import SwiftUI

struct KeywordSummaryCardItem: Identifiable, Hashable {
    let id: String
    let keyword: String
    let displayText: String
    let count: Int
}

struct KeywordSummaryCard: View {
    let items: [KeywordSummaryCardItem]
    let selectedKeyword: String?
    var isUpdating: Bool = false
    let onClear: () -> Void
    let onSelect: (String?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("키워드 요약")
                        .font(Typography.headline)
                        .foregroundStyle(AppColor.textPrimary)

                    Text("탭으로 해당 키워드 사진을 확인할 수 있습니다.")
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                }

                Spacer()

                if selectedKeyword != nil {
                    Button("초기화") {
                        onClear()
                    }
                    .font(Typography.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(AppColor.accent)
                }
            }

            if isUpdating {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("키워드 요약 갱신 중")
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                }
            }

            if !items.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Spacing.xs) {
                        ForEach(items) { item in
                            let isSelected = selectedKeyword == item.keyword

                            Button(item.displayText) {
                                onSelect(isSelected ? nil : item.keyword)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .background(
                                Group {
                                    if isSelected {
                                        AppColor.premiumGradient
                                    } else {
                                        AppColor.backgroundTertiary
                                    }
                                }
                            )
                            .foregroundStyle(isSelected ? AppColor.primaryText : AppColor.textPrimary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? AppColor.primary : AppColor.separator, lineWidth: 1)
                            )
                        }
                    }
                }
            } else if !isUpdating {
                Text("키워드 분석 결과가 없습니다.")
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .padding(Spacing.md)
        .premiumCard()
    }
}
