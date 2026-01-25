#if DEBUG
import Foundation

enum PreviewSampleData {
    // MARK: - Screenshots
    static let screenshots: [PhotoIssue] = [
        PhotoIssue(
            previewId: "preview-screenshot-1",
            assetIdentifier: "sample_screenshot_1",
            issueType: .screenshot,
            aspectRatio: 9.0 / 19.5
        ),
        PhotoIssue(
            previewId: "preview-screenshot-2",
            assetIdentifier: "sample_screenshot_2",
            issueType: .screenshot,
            aspectRatio: 9.0 / 16.0
        ),
        PhotoIssue(
            previewId: "preview-screenshot-3",
            assetIdentifier: "sample_screenshot_3",
            issueType: .screenshot,
            aspectRatio: 9.0 / 19.5
        ),
        PhotoIssue(
            previewId: "preview-screenshot-4",
            assetIdentifier: "sample_screenshot_4",
            issueType: .screenshot,
            aspectRatio: 9.0 / 16.0
        ),
        PhotoIssue(
            previewId: "preview-screenshot-5",
            assetIdentifier: "sample_screenshot_5",
            issueType: .screenshot,
            aspectRatio: 9.0 / 19.5
        )
    ]

    // MARK: - Large Files
    static let largeFiles: [PhotoIssue] = [
        PhotoIssue(
            previewId: "preview-large-1",
            assetIdentifier: "sample_large_1",
            issueType: .largeFile,
            aspectRatio: 4.0 / 3.0
        ),
        PhotoIssue(
            previewId: "preview-large-2",
            assetIdentifier: "sample_large_2",
            issueType: .largeFile,
            aspectRatio: 3.0 / 4.0
        ),
        PhotoIssue(
            previewId: "preview-large-3",
            assetIdentifier: "sample_large_3",
            issueType: .largeFile,
            aspectRatio: 16.0 / 9.0
        )
    ]

    // MARK: - Corrupted
    static let corrupted: [PhotoIssue] = [
        PhotoIssue(
            previewId: "preview-corrupted-1",
            assetIdentifier: "sample_corrupted_1",
            issueType: .corrupted,
            aspectRatio: 1.0
        )
    ]

    // MARK: - Download Failed
    static let downloadFailed: [PhotoIssue] = [
        PhotoIssue(
            previewId: "preview-download-failed-1",
            assetIdentifier: "sample_download_failed_1",
            issueType: .downloadFailed,
            aspectRatio: 4.0 / 3.0
        ),
        PhotoIssue(
            previewId: "preview-download-failed-2",
            assetIdentifier: "sample_download_failed_2",
            issueType: .downloadFailed,
            aspectRatio: 16.0 / 9.0
        )
    ]

    // MARK: - Duplicate Groups
    static let duplicateGroups: [DuplicateGroup] = [
        DuplicateGroup(
            id: "dup-group-1",
            assetIdentifiers: [
                "sample_dup_1a",
                "sample_dup_1b",
                "sample_dup_1c"
            ],
            suggestedOriginalId: "sample_dup_1a",
            similarity: 0.98,
            potentialSavings: 15_728_640
        ),
        DuplicateGroup(
            id: "dup-group-2",
            assetIdentifiers: [
                "sample_dup_2a",
                "sample_dup_2b"
            ],
            suggestedOriginalId: "sample_dup_2a",
            similarity: 0.95,
            potentialSavings: 8_388_608
        )
    ]

    // MARK: - Duplicate Issues
    static let duplicateIssues: [PhotoIssue] = {
        duplicateGroups.flatMap { group in
            group.assetIdentifiers.enumerated().map { index, assetId in
                PhotoIssue(
                    previewId: "preview-\(assetId)",
                    assetIdentifier: assetId,
                    issueType: .duplicate,
                    metadata: IssueMetadata(duplicateGroupId: group.id),
                    aspectRatio: 4.0 / 3.0
                )
            }
        }
    }()

    // MARK: - Empty Scan Result
    static let emptyScanResult = ScanResult(
        totalPhotos: 0,
        issues: [],
        summaries: [],
        duplicateGroups: [],
        scannedAt: Date()
    )

    // MARK: - Normal Scan Result
    static let normalScanResult: ScanResult = {
        let allIssues = screenshots + largeFiles + corrupted + downloadFailed + duplicateIssues
        let summaries = [
            IssueSummary(
                issueType: .screenshot,
                count: screenshots.count,
                totalSize: Int64(screenshots.count * 2_097_152)
            ),
            IssueSummary(
                issueType: .largeFile,
                count: largeFiles.count,
                totalSize: Int64(largeFiles.count * 10_485_760)
            ),
            IssueSummary(
                issueType: .corrupted,
                count: corrupted.count,
                totalSize: 0
            ),
            IssueSummary(
                issueType: .downloadFailed,
                count: downloadFailed.count,
                totalSize: 0
            ),
            IssueSummary(
                issueType: .duplicate,
                count: duplicateIssues.count,
                totalSize: duplicateGroups.reduce(0) { $0 + $1.potentialSavings }
            )
        ]

        return ScanResult(
            totalPhotos: 1000,
            issues: allIssues,
            summaries: summaries,
            duplicateGroups: duplicateGroups,
            scannedAt: Date()
        )
    }()

    // MARK: - Bulk Scan Result
    static let bulkScanResult: ScanResult = {
        let bulkScreenshots = (1...50).map { index in
            PhotoIssue(
                previewId: "preview-screenshot-bulk-\(index)",
                assetIdentifier: "sample_screenshot_bulk_\(index)",
                issueType: .screenshot,
                aspectRatio: [9.0/19.5, 9.0/16.0, 16.0/9.0].randomElement()!
            )
        }

        let summaries = [
            IssueSummary(
                issueType: .screenshot,
                count: bulkScreenshots.count,
                totalSize: Int64(bulkScreenshots.count * 2_097_152)
            )
        ]

        return ScanResult(
            totalPhotos: 5000,
            issues: bulkScreenshots,
            summaries: summaries,
            duplicateGroups: [],
            scannedAt: Date()
        )
    }()

    // MARK: - Issue Summaries
    static let summaries: [IssueSummary] = [
        IssueSummary(
            issueType: .screenshot,
            count: 5,
            totalSize: 10_485_760
        ),
        IssueSummary(
            issueType: .largeFile,
            count: 3,
            totalSize: 31_457_280
        ),
        IssueSummary(
            issueType: .corrupted,
            count: 1,
            totalSize: 0
        ),
        IssueSummary(
            issueType: .downloadFailed,
            count: 2,
            totalSize: 0
        ),
        IssueSummary(
            issueType: .duplicate,
            count: 5,
            totalSize: 24_117_248
        )
    ]
}
#endif
