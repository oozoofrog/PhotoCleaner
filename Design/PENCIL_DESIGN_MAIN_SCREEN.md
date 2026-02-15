# PhotoCleaner Main Screen Pencil Design

## 디자인 파일
- `Design/main-dashboard.pen`

## 목적
- 실제 구현 코드(`DashboardView`, `AllPhotosView`, `SettingsView`)와 1:1 대응되는 화면/상태/컴포넌트 기준을 유지한다.
- 키워드 분석 및 키워드 앨범 생성 흐름까지 포함한 UI 협업 기준을 제공한다.

## 코드 기반 프레임 구성 (동기화 완료)

1. 대시보드
- `Main Dashboard`
- `SummaryCard` 구조 반영:
`전체 요약`, 진행률 바/퍼센트 텍스트, 마지막 검사 시각, `다시 검사하기`, `중복 사진 찾기`
- `KeywordSummaryCard` 구조 반영:
제목/설명/초기화/갱신 상태/키워드 칩/빈 상태 힌트
- `IssueCard` 4개 반영:
`다운로드 실패`, `손상됨`, `스크린샷`, `대용량` + 아이콘/카운트/상태
- `DuplicateCard` 반영:
`중복 그룹`, 절감 용량, 상세 진입 힌트

2. 전체 사진 화면
- `All Photos - Keyword Filter`
- `All Photos - Selection Mode`
- `All Photos - Empty`
- `All Photos - Empty (Filtered)`
- `AssetThumbnailView` 기준 선택 배지(체크/원형)와 하단 선택 툴바 반영

3. 키워드 앨범 생성 흐름
- `Keyword Album - Entry`
- `Keyword Album - Create`
- `Keyword Album - Success`
- 키워드 선택 -> 앨범명/옵션 입력 -> 생성 완료 액션(`앨범 보기`/`닫기`) 흐름 반영

4. 설정 화면(키워드 분석 관련)
- `Settings - Keyword Analysis`
- `SettingsView`의 `검사 설정` 중 키워드 관련 항목 반영:
`키워드 분석` 토글, `키워드 신뢰도 임계값` 슬라이더, `자동 검사` 토글

## 상태별 화면 기준

1. `needsPermission`
- `PermissionRequestView` 단일 노출

2. `ready`
- Summary + Keyword + Issue + Duplicate 조건부 노출

3. `scanning`
- SummaryCard 진행률/진행 텍스트 노출
- 이슈/중복 데이터는 live 값 기반 갱신

4. `error`
- `ErrorView` + 재시도 액션

## 네비게이션 기준

1. 우상단 `gearshape`
- `SettingsView` 이동

2. 이슈 카드 탭
- 해당 `IssueListView` 이동

3. `View All Photos` 또는 키워드 칩 탭
- `AllPhotosView` 이동
- 키워드 탭 시 `initialKeywordFilter` 전달

4. 키워드 앨범 버튼 탭
- 키워드 앨범 생성 흐름(`Entry -> Create -> Success`) 이동

## 최신 동기화 체크포인트 (2026-02-15)

1. 키워드 요약 조회 limit: `10`
2. 키워드 카드 노출 조건: `keywordSummaries.isEmpty == false`
3. 중복 카드 노출 조건: `isScanning ? liveDuplicateGroupCount > 0 : hasDuplicates`
4. 스캔 상태에서도 대시보드 유지(`ready`, `scanning` 공통 렌더링)
5. 최종 빌드/테스트 게이트: `./scripts/build-check.sh test` 통과(`errors: 0`, `warnings: 0`, `failed_tests: 0`)
