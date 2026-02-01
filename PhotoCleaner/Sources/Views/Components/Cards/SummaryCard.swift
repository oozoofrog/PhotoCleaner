//
//  SummaryCard.swift
//  PhotoCleaner
//
//  대시보드 요약 카드 컴포넌트
//

import SwiftUI

struct SummaryCard: View {
    let totalPhotos: Int
    let totalIssues: Int
    let lastScanDate: String?
    let isScanning: Bool
    let scanProgress: ScanProgress?
    var liveIssueCount: Int = 0
    var scanWasCancelled: Bool = false
    var cancelledProcessedCount: Int = 0
    let onScan: () -> Void
    var onCancel: (() -> Void)?
    var onViewAllPhotos: (() -> Void)?

    /// 현재 표시할 이슈 개수
    private var displayIssueCount: Int {
        isScanning ? liveIssueCount : totalIssues
    }

    /// 현재 표시할 사진 개수
    private var displayPhotoCount: Int {
        if isScanning, let progress = scanProgress {
            return progress.total > 0 ? progress.total : totalPhotos
        }
        return totalPhotos
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            // 스캔 중 인라인 프로그레스 바
            if isScanning, let progress = scanProgress, progress.total > 0 {
                VStack(spacing: Spacing.xs) {
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .fill(AppColor.backgroundTertiary)
                            .frame(height: 6)

                        // Gradient progress fill
                        RoundedRectangle(cornerRadius: CornerRadius.sm)
                            .fill(AppColor.premiumGradient)
                            .frame(width: CGFloat(progress.progress) * 300, height: 6)
                            .animation(.spring(response: 0.3), value: progress.progress)
                    }
                    .frame(height: 6)

                    HStack {
                        Text(progress.displayText)
                            .font(Typography.caption)
                            .foregroundStyle(AppColor.textSecondary)
                        Spacer()
                        Text("\(Int(progress.progress * 100))%")
                            .font(Typography.caption)
                            .foregroundStyle(AppColor.textTertiary)
                    }
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("전체 요약")
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.textSecondary)

                    if displayPhotoCount > 0 || isScanning {
                        Button {
                            onViewAllPhotos?()
                        } label: {
                            HStack(spacing: Spacing.xs) {
                                Text("\(displayPhotoCount.formatted())장")
                                    .font(Typography.headline)
                                    .foregroundStyle(AppColor.primary)
                                Text("중 ")
                                    .font(Typography.headline)
                                    .foregroundStyle(AppColor.textPrimary)
                                // 실시간 이슈 카운트 (애니메이션)
                                Text("\(displayIssueCount)")
                                    .font(Typography.headline)
                                    .foregroundStyle(AppColor.accent)
                                    .accentGlow()
                                    .contentTransition(.numericText())
                                    .animation(.spring(response: 0.3), value: displayIssueCount)
                                Text("장에 문제 발견")
                                    .font(Typography.headline)
                                    .foregroundStyle(AppColor.textPrimary)
                                if !isScanning {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: IconSize.sm))
                                        .foregroundStyle(AppColor.textTertiary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isScanning)
                    } else {
                        Text("검사를 시작해 주세요")
                            .font(Typography.headline)
                            .foregroundStyle(AppColor.textPrimary)
                    }

                    // 마지막 스캔 날짜 또는 스캔 상태
                    if isScanning {
                        Text("검사 중...")
                            .font(Typography.caption)
                            .foregroundStyle(AppColor.primary)
                    } else if scanWasCancelled {
                        Text("검사가 취소되었습니다 (\(cancelledProcessedCount)장 처리됨)")
                            .font(Typography.caption)
                            .foregroundStyle(AppColor.accent)
                    } else if let lastScan = lastScanDate {
                        Text("마지막 검사: \(lastScan)")
                            .font(Typography.caption)
                            .foregroundStyle(AppColor.textTertiary)
                    }
                }

                Spacer()

                if displayIssueCount > 0 {
                    Text("\(displayIssueCount)")
                        .font(Typography.largeNumber)
                        .foregroundStyle(AppColor.accent)
                        .accentGlow()
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3), value: displayIssueCount)
                }
            }

            // 스캔/취소 버튼
            if isScanning {
                Button {
                    onCancel?()
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("검사 취소하기")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.destructive)
            } else {
                Button(action: onScan) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text(totalPhotos > 0 ? "다시 검사하기" : "검사 시작하기")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary)
            }
        }
        .padding(Spacing.lg)
        .premiumCard()
    }
}
