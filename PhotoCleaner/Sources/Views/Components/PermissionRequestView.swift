//
//  PermissionRequestView.swift
//  PhotoCleaner
//

import SwiftUI

struct PermissionRequestView: View {
    @Bindable var viewModel: DashboardViewModel

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // 아이콘
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: IconSize.hero))
                .foregroundStyle(AppColor.primary)

            // 제목
            Text("사진 접근 권한이 필요해요")
                .font(Typography.title)
                .foregroundStyle(AppColor.textPrimary)

            // 설명
            VStack(spacing: Spacing.sm) {
                Text("PhotoCleaner가 사진첩의 문제를")
                Text("찾고 정리하려면 사진 접근 권한이 필요합니다.")
            }
            .font(Typography.body)
            .foregroundStyle(AppColor.textSecondary)
            .multilineTextAlignment(.center)

            // 안내 사항
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label("사진은 기기에서만 분석됩니다", systemImage: "lock.shield")
                Label("외부로 전송되지 않습니다", systemImage: "icloud.slash")
            }
            .font(Typography.caption)
            .foregroundStyle(AppColor.textTertiary)
            .padding(Spacing.md)
            .background(AppColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))

            Spacer()

            // 버튼
            VStack(spacing: Spacing.sm) {
                if viewModel.permissionService.status == .denied {
                    Button("설정에서 허용하기") {
                        viewModel.permissionService.openSettings()
                    }
                    .buttonStyle(.primary)
                } else {
                    Button("권한 허용하기") {
                        Task { await viewModel.requestPermission() }
                    }
                    .buttonStyle(.primary)
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
        .padding(Spacing.lg)
    }
}
