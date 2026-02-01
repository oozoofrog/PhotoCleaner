//
//  IssueInfoHeader.swift
//  PhotoCleaner
//
//  재사용 가능한 이슈 정보 헤더 컴포넌트
//

import SwiftUI

struct IssueInfoHeader<AdditionalContent: View>: View {
    let issueType: IssueType
    @ViewBuilder let additionalContent: () -> AdditionalContent

    init(
        issueType: IssueType,
        @ViewBuilder additionalContent: @escaping () -> AdditionalContent = { EmptyView() }
    ) {
        self.issueType = issueType
        self.additionalContent = additionalContent
    }

    var body: some View {
        HStack(spacing: 0) {
            // Gold accent line
            LinearGradient(
                colors: [
                    Color(red: 0.85, green: 0.65, blue: 0.13),
                    Color(red: 0.95, green: 0.76, blue: 0.20)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: 3)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label(issueType.displayName, systemImage: issueType.iconName)
                    .font(Typography.headline)
                    .foregroundStyle(issueType.color)

                Text(issueType.userDescription)
                    .font(Typography.subheadline)
                    .foregroundStyle(AppColor.textSecondary)

                additionalContent()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
        }
        .glassCard()
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        .padding(.horizontal, Spacing.sm)
    }
}

#if DEBUG
#Preview("IssueInfoHeader - Screenshot") {
    IssueInfoHeader(issueType: .screenshot)
}

#Preview("IssueInfoHeader - With Additional Content") {
    IssueInfoHeader(issueType: .downloadFailed) {
        VStack(alignment: .leading) {
            Divider()
            Text("추가 콘텐츠")
                .font(Typography.caption)
        }
    }
}
#endif
