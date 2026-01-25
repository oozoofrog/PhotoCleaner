//
//  DateFilterPicker.swift
//  PhotoCleaner
//
//  날짜 필터 선택 컴포넌트
//

import SwiftUI

enum DateFilter: String, CaseIterable, Identifiable {
    case all = "전체"
    case today = "오늘"
    case thisWeek = "이번 주"
    case thisMonth = "이번 달"
    case older = "오래된 것"

    var id: String { rawValue }
}

struct DateFilterPicker: View {
    @Binding var selectedFilter: DateFilter
    let counts: [DateFilter: Int]
    let totalCount: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(DateFilter.allCases) { filter in
                    let count = filter == .all ? totalCount : (counts[filter] ?? 0)
                    Button {
                        withAnimation { selectedFilter = filter }
                    } label: {
                        Text("\(filter.rawValue) (\(count))")
                            .font(Typography.subheadline)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .background(selectedFilter == filter ? AppColor.primary : AppColor.backgroundSecondary)
                            .foregroundStyle(selectedFilter == filter ? .white : AppColor.textPrimary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.sm)
        }
    }
}

#if DEBUG
#Preview("DateFilterPicker") {
    DateFilterPicker(
        selectedFilter: .constant(.all),
        counts: [.today: 5, .thisWeek: 10, .thisMonth: 20, .older: 15],
        totalCount: 50
    )
}
#endif
