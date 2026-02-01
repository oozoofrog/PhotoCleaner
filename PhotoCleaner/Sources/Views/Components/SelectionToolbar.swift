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
                    .foregroundStyle(AppColor.accent)
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
        .background {
            ZStack(alignment: .top) {
                // Glass material background
                Color.clear
                    .background(.ultraThinMaterial)

                // Subtle top border gradient
                LinearGradient(
                    colors: [
                        AppColor.textSecondary.opacity(0.2),
                        AppColor.textSecondary.opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
