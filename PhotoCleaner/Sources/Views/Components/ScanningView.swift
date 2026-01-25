//
//  ScanningView.swift
//  PhotoCleaner
//

import SwiftUI

struct ScanningView: View {
    let progress: ScanProgress?

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)

            Text(progress?.displayText ?? "검사 중...")
                .font(Typography.headline)
                .foregroundStyle(AppColor.textPrimary)

            if let progress = progress, progress.total > 0 {
                ProgressView(value: progress.progress)
                    .progressViewStyle(.linear)
                    .padding(.horizontal, Spacing.xxl)
            }

            Spacer()
        }
    }
}
