//
//  JustifiedPhotoGrid.swift
//  PhotoCleaner
//
//  Row-justified 사진 그리드 레이아웃
//  iOS Photos 앱 스타일로 행별 높이 고정, 너비 가변
//

import SwiftUI

// MARK: - Layout Value Key

/// 각 사진의 종횡비를 레이아웃에 전달하기 위한 키
struct AspectRatioKey: LayoutValueKey {
    nonisolated static let defaultValue: CGFloat = 1.0
}

extension View {
    /// 사진의 종횡비를 레이아웃에 전달
    func photoAspectRatio(_ ratio: CGFloat) -> some View {
        layoutValue(key: AspectRatioKey.self, value: ratio)
    }
}

// MARK: - Justified Photo Grid Layout

/// Row-justified 사진 그리드 레이아웃
///
/// 각 행의 높이를 동일하게 유지하면서 사진들이 자연 비율을 유지합니다.
/// 행 내 사진들은 컨테이너 너비에 맞게 스케일 조정됩니다.
struct JustifiedPhotoGrid: Layout {
    /// 목표 행 높이 (실제 높이는 스케일링에 따라 약간 달라질 수 있음)
    let targetRowHeight: CGFloat

    /// 아이템 간 간격
    let spacing: CGFloat

    /// 마지막 행 확대 여부 (false면 원래 크기 유지)
    let expandLastRow: Bool

    /// - Parameters:
    ///   - targetRowHeight: 목표 행 높이 (기본값: 120pt, GridLayout.rowHeight)
    ///   - spacing: 아이템 간 간격 (기본값: 4pt, Spacing.xs)
    ///   - expandLastRow: 마지막 행 확대 여부
    init(
        targetRowHeight: CGFloat = 120,
        spacing: CGFloat = 4,
        expandLastRow: Bool = false
    ) {
        self.targetRowHeight = targetRowHeight
        self.spacing = spacing
        self.expandLastRow = expandLastRow
    }

    // MARK: - Layout Protocol

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }

        let containerWidth = proposal.width ?? 300
        let rows = computeRows(containerWidth: containerWidth, subviews: subviews)

        let totalHeight = rows.reduce(0) { sum, row in
            sum + row.scaledHeight
        } + CGFloat(max(0, rows.count - 1)) * spacing

        return CGSize(width: containerWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }

        let rows = computeRows(containerWidth: bounds.width, subviews: subviews)
        var yOffset = bounds.minY

        for (rowIndex, row) in rows.enumerated() {
            var xOffset = bounds.minX
            let isLastRow = rowIndex == rows.count - 1
            let shouldExpand = !isLastRow || expandLastRow

            for item in row.items {
                let itemWidth = shouldExpand ? item.scaledWidth : item.naturalWidth
                let itemHeight = shouldExpand ? row.scaledHeight : targetRowHeight

                let itemSize = CGSize(width: itemWidth, height: itemHeight)
                subviews[item.index].place(
                    at: CGPoint(x: xOffset, y: yOffset),
                    proposal: ProposedViewSize(itemSize)
                )

                xOffset += itemWidth + spacing
            }

            yOffset += (shouldExpand ? row.scaledHeight : targetRowHeight) + spacing
        }
    }

    // MARK: - Row Computation

    private struct RowItem {
        let index: Int
        let aspectRatio: CGFloat
        let naturalWidth: CGFloat
        var scaledWidth: CGFloat
    }

    private struct Row {
        var items: [RowItem]
        var naturalWidth: CGFloat  // spacing 포함한 자연 너비 합
        var scaledHeight: CGFloat
    }

    /// 행 배치 계산
    private func computeRows(containerWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentRow = Row(items: [], naturalWidth: 0, scaledHeight: targetRowHeight)

        for (index, subview) in subviews.enumerated() {
            let aspectRatio = subview[AspectRatioKey.self]
            let naturalWidth = targetRowHeight * aspectRatio

            let newItem = RowItem(
                index: index,
                aspectRatio: aspectRatio,
                naturalWidth: naturalWidth,
                scaledWidth: naturalWidth
            )

            // 현재 행에 아이템 추가 시 예상 너비
            let spacingForNewItem = currentRow.items.isEmpty ? 0 : spacing
            let projectedWidth = currentRow.naturalWidth + spacingForNewItem + naturalWidth

            if currentRow.items.isEmpty || projectedWidth <= containerWidth {
                // 현재 행에 추가
                currentRow.items.append(newItem)
                currentRow.naturalWidth = projectedWidth
            } else {
                // 현재 행 완료 후 스케일 조정
                scaleRow(&currentRow, toWidth: containerWidth)
                rows.append(currentRow)

                // 새 행 시작
                currentRow = Row(
                    items: [newItem],
                    naturalWidth: naturalWidth,
                    scaledHeight: targetRowHeight
                )
            }
        }

        // 마지막 행 처리
        if !currentRow.items.isEmpty {
            if expandLastRow {
                scaleRow(&currentRow, toWidth: containerWidth)
            }
            rows.append(currentRow)
        }

        return rows
    }

    /// 행을 컨테이너 너비에 맞게 스케일 조정
    private func scaleRow(_ row: inout Row, toWidth containerWidth: CGFloat) {
        guard !row.items.isEmpty else { return }

        // spacing을 제외한 순수 아이템 너비의 합
        let totalSpacing = CGFloat(row.items.count - 1) * spacing
        let availableWidth = containerWidth - totalSpacing
        let naturalItemsWidth = row.items.reduce(0) { $0 + $1.naturalWidth }

        guard naturalItemsWidth > 0 else { return }

        let scale = availableWidth / naturalItemsWidth
        row.scaledHeight = targetRowHeight * scale

        // 각 아이템 너비 스케일 조정
        for i in row.items.indices {
            row.items[i].scaledWidth = row.items[i].naturalWidth * scale
        }
    }
}

// MARK: - Preview

#if DEBUG
struct JustifiedPhotoGridPreview: View {
    // 다양한 종횡비 테스트 데이터
    let aspectRatios: [CGFloat] = [
        1.33,   // 4:3 가로
        0.75,   // 3:4 세로
        1.78,   // 16:9 가로
        1.0,    // 1:1 정사각형
        0.56,   // 9:16 세로
        1.5,    // 3:2 가로
        0.67,   // 2:3 세로
        1.33,
        1.0,
        1.78,
        0.75,
        1.5
    ]

    var body: some View {
        ScrollView {
            JustifiedPhotoGrid(targetRowHeight: 100, spacing: 4) {
                ForEach(Array(aspectRatios.enumerated()), id: \.offset) { index, ratio in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hue: Double(index) / 12, saturation: 0.7, brightness: 0.9))
                        .overlay {
                            Text(String(format: "%.2f", ratio))
                                .font(.caption2)
                                .foregroundStyle(.white)
                        }
                        .photoAspectRatio(ratio)
                }
            }
            .padding(.horizontal, 8)
        }
    }
}

#Preview("Justified Grid") {
    JustifiedPhotoGridPreview()
}
#endif
