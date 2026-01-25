//
//  ErrorView.swift
//  PhotoCleaner
//

import SwiftUI

struct ErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: IconSize.hero))
                .foregroundStyle(AppColor.warning)

            Text("오류가 발생했어요")
                .font(Typography.title)
                .foregroundStyle(AppColor.textPrimary)

            Text(message)
                .font(Typography.body)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button("다시 시도", action: onRetry)
                .buttonStyle(.primary)
                .padding(.horizontal, Spacing.lg)
        }
        .padding(Spacing.lg)
    }
}
