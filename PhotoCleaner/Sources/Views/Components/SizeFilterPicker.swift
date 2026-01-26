//
//  SizeFilterPicker.swift
//  PhotoCleaner
//
//  파일 크기 필터 선택 컴포넌트
//

import SwiftUI

struct SizeFilterPicker: View {
    @Binding var selectedOption: LargeFileSizeOption
    var onOptionChange: (@Sendable (LargeFileSizeOption) async -> Void)?

    @State private var sizeChangeTask: Task<Void, Never>?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(LargeFileSizeOption.allCases) { option in
                    Button {
                        guard option != selectedOption else { return }
                        sizeChangeTask?.cancel()
                        sizeChangeTask = Task {
                            await onOptionChange?(option)
                        }
                    } label: {
                        Text("\(option.displayName) 이상")
                            .font(Typography.subheadline)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .background(selectedOption == option ? AppColor.primary : AppColor.backgroundSecondary)
                            .foregroundStyle(selectedOption == option ? .white : AppColor.textPrimary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.sm)
        }
        .onDisappear {
            sizeChangeTask?.cancel()
        }
    }
}

#if DEBUG
#Preview("SizeFilterPicker") {
    SizeFilterPicker(
        selectedOption: .constant(.mb10),
        onOptionChange: nil
    )
}
#endif
