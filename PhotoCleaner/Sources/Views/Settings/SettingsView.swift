//
//  SettingsView.swift
//  PhotoCleaner
//

import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    var onClearCache: (() -> Void)?

    @State private var showResetConfirmation = false
    @State private var showClearCacheConfirmation = false

    var body: some View {
        List {
            scanSettingsSection
            displaySettingsSection
            dataSection
            appInfoSection
        }
        .navigationTitle("설정")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog(
            "설정 초기화",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("초기화", role: .destructive) {
                settings.resetToDefaults()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("모든 설정을 기본값으로 되돌립니다.")
        }
        .confirmationDialog(
            "검사 기록 초기화",
            isPresented: $showClearCacheConfirmation,
            titleVisibility: .visible
        ) {
            Button("초기화", role: .destructive) {
                onClearCache?()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("캐시된 검사 결과가 삭제됩니다.\n다음 검사 시 처음부터 다시 분석합니다.")
        }
    }

    // MARK: - Sections

    private var scanSettingsSection: some View {
        Section {
            Picker("대용량 기준", selection: $settings.largeFileSizeOption) {
                ForEach(LargeFileSizeOption.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }

            Picker("중복 감지 모드", selection: $settings.duplicateDetectionMode) {
                ForEach(DuplicateDetectionMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }

            if settings.duplicateDetectionMode == .includeSimilar {
                Picker("유사도 기준", selection: $settings.similarityThreshold) {
                    ForEach(SimilarityThreshold.allCases) { threshold in
                        Text(threshold.displayName).tag(threshold)
                    }
                }
            }

            Toggle("자동 검사", isOn: $settings.autoScanEnabled)
        } header: {
            Text("검사 설정")
        } footer: {
            Text("자동 검사를 켜면 앱 실행 시 자동으로 검사를 시작합니다.")
        }
    }

    private var displaySettingsSection: some View {
        Section {
            Picker("썸네일 크기", selection: $settings.thumbnailSize) {
                ForEach(ThumbnailSize.allCases) { size in
                    Text(size.displayName).tag(size)
                }
            }

            Picker("정렬 기준", selection: $settings.sortOrder) {
                ForEach(SortOrder.allCases) { order in
                    Text(order.displayName).tag(order)
                }
            }
        } header: {
            Text("표시 설정")
        }
    }

    private var dataSection: some View {
        Section {
            Button("검사 기록 초기화") {
                showClearCacheConfirmation = true
            }
            .foregroundStyle(AppColor.warning)

            Button("모든 설정 초기화") {
                showResetConfirmation = true
            }
            .foregroundStyle(AppColor.warning)
        } header: {
            Text("데이터")
        } footer: {
            Text("검사 기록을 초기화하면 다음 검사 시 모든 사진을 다시 분석합니다.")
        }
    }

    private var appInfoSection: some View {
        Section {
            HStack {
                Text("버전")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(AppColor.textSecondary)
            }

            HStack {
                Text("빌드")
                Spacer()
                Text(buildNumber)
                    .foregroundStyle(AppColor.textSecondary)
            }
        } header: {
            Text("앱 정보")
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - Preview

#Preview("Settings") {
    NavigationStack {
        SettingsView(settings: AppSettings.shared)
    }
}
