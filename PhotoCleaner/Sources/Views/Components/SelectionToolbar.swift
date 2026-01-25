//
//  SelectionToolbar.swift
//  PhotoCleaner
//
//  재사용 가능한 선택 툴바 컴포넌트
//

import SwiftUI

struct SelectionToolbar: View {
    let selectedCount: Int
    let totalCount: Int
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Button {
                if selectedCount == totalCount {
                    onDeselectAll()
                } else {
                    onSelectAll()
                }
            } label: {
                Text(selectedCount == totalCount ? "전체 해제" : "전체 선택")
            }

            Spacer()

            Text("\(selectedCount)장 선택됨")
                .font(Typography.caption)
                .foregroundStyle(AppColor.textSecondary)

            Spacer()

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("삭제", systemImage: "trash")
            }
        }
        .padding(Spacing.md)
        .background(.ultraThinMaterial)
    }
}
