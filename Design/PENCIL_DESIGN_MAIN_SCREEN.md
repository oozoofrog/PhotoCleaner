# PhotoCleaner Main Screen Pencil Design

## 목적
- 메인 화면(`DashboardView`)의 정보 위계와 화면 전환을 손스케치 스타일로 빠르게 공유하기 위한 디자인 기준 파일.
- 개발 구현과 1:1로 대응되는 레이아웃 기준을 제공한다.

## 화면 구조 (Pencil Wireframe)

```text
+--------------------------------------------------+
| PhotoCleaner                               [gear]|
+--------------------------------------------------+
|                                                  |
|  [ Summary Card ]                                |
|  - totalPhotos                                   |
|  - totalIssues                                   |
|  - lastScanDate                                  |
|  - Action: Scan / Cancel / View All Photos       |
|  - Action: Scan Duplicates                       |
|                                                  |
|  [ Keyword Summary Card ] (keywordSummaries>0)   |
|  [ #cat (12) ] [ #dog (9) ] [ #beach (7) ] ...   |
|  - tap keyword -> AllPhotos with filter          |
|  - clear selected keyword                         |
|                                                  |
|  [ Issue Section ] (hasScanned || isScanning)    |
|  "문제 유형"                                      |
|  +----------------+  +----------------+          |
|  | downloadFailed |  | corrupted      |          |
|  +----------------+  +----------------+          |
|  +----------------+  +----------------+          |
|  | screenshot     |  | largeFile      |          |
|  +----------------+  +----------------+          |
|                                                  |
|  [ Duplicate Section ] (has duplicates only)     |
|  "중복 사진"                                      |
|  +--------------------------------------------+  |
|  | groupCount / duplicateCount / savings      |  |
|  +--------------------------------------------+  |
|                                                  |
+--------------------------------------------------+
```

## 상태별 화면

1. `needsPermission`
- `PermissionRequestView` 단일 노출.

2. `ready`
- Summary + Keyword + Issue + Duplicate 섹션 조건부 노출.

3. `scanning`
- SummaryCard 진행률 표시.
- Issue/duplicate는 live 데이터로 갱신.
- Issue 카드 탭 비활성화.

4. `error`
- `ErrorView` 노출 + 재시도 액션.

## 네비게이션

1. 우상단 `gearshape`
- `SettingsView` 이동.

2. 이슈 카드 탭
- 해당 `IssueListView` 이동.

3. `View All Photos` 또는 키워드 칩 탭
- `AllPhotosView` 이동.
- 키워드 칩 탭 시 `initialKeywordFilter` 전달.

## 레이아웃/토큰 기준

- 배경: `premiumBackground()`
- 콘텐츠 컨테이너: `ScrollView` + `VStack(spacing: Spacing.lg)`
- 화면 여백: `.padding(Spacing.md)`
- 이슈 카드: 2열 `LazyVGrid`, 열 간격 `Spacing.md`

## 최신 구현 동기화 체크포인트

1. 키워드 요약 조회 limit: `10`
2. 키워드 카드 노출 조건: `keywordSummaries.isEmpty == false`
3. 중복 카드 노출 조건: `isScanning ? liveDuplicateGroupCount > 0 : hasDuplicates`
4. 스캔 상태에서도 대시보드 유지(`ready`, `scanning` 공통 렌더링)
