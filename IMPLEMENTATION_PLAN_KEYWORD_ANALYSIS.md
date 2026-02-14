# PhotoCleaner 키워드 분석 기능 구현 상세 계획 (v1)

## 0. 문서 정보

| 항목 | 내용 |
|---|---|
| 작성일 | 2026-02-14 |
| 기준 문서 | `FEATURE_SPEC_KEYWORD_ANALYSIS.md` |
| 대상 브랜치 | `feature/photo-keyword-analysis` |
| 목표 | 키워드 분석 MVP를 실제 배포 가능한 수준으로 구현 |

### 0.1 진행 상황 업데이트 규칙
- 작업 진행 중 이 문서를 기준 상태 문서로 유지한다.
- 코드 변경 직후 해당 Phase의 `작업`, `검증`, `원칙 준수 게이트` 항목에 상태를 즉시 반영한다.
- 진행상황은 문서 마지막 별도 로그가 아니라 각 작업 내용(Phase 본문)에 기록한다.
- 테스트/빌드 실패 시 실패 원인과 재현 명령을 해당 Phase `검증` 바로 아래에 남긴다.
- 작업이 끝난 직후(요청 유무와 무관) 관련 테스트/검증 명령을 실행하고 결과를 즉시 반영한다.

---

## 1. 개발 방법론 (상단 배치)

- TDD: Red -> Green -> Refactor 순서로 테스트가 설계를 이끈다.
- DDD: 도메인 경계(`Issue Detection`, `Keyword Analysis`, `Photo Catalog Persistence`)를 분리한다.
- OOP: 단일 책임, 캡슐화, 프로토콜 기반 의존성을 유지한다.
- Factory: 객체 생성 로직을 사용 로직에서 분리해 생성 복잡도를 낮춘다.
- Pure DI: DI 컨테이너 없이 Composition Root에서 명시적으로 의존성을 조립한다.
- Kent Beck Tidy First: 구조 변경과 동작 변경을 같은 커밋/PR에 섞지 않는다.

상세 적용 규칙은 `## 4. 설계 원칙 (TDD/DDD/OOP/Factory/Pure DI 반영)`과 `## 5. 작업 단계`에 반영한다.

---

## 2. 구현 목표와 완료 기준 (Definition of Done)

### 2.1 구현 목표
- 사진 스캔 시 키워드(최대 3개/사진)를 온디바이스 분석으로 생성한다.
- 저장소를 GRDB 단일 체계로 통합한다.
- `AllPhotosView` 키워드 필터와 `DashboardView` 키워드 요약 카드를 제공한다.
- 표시 언어는 디바이스 로케일 기반 자동 선택으로 동작한다.

### 2.2 완료 기준
- 설정에서 키워드 분석 On/Off, confidence 0.8 기본값이 반영된다.
- 스캔 완료 후 키워드 데이터가 GRDB에 저장되고 재실행 시 재사용된다.
- 전체 사진 화면 필터와 대시보드 요약 카드가 동일한 저장소 데이터를 사용한다.
- 기존 이슈 스캔(다운로드 실패/손상/스크린샷/대용량/중복) 회귀가 없다.
- 전체 테스트 및 빌드 명령이 통과한다.

---

## 3. 범위

### 3.1 In Scope
- GRDB 의존성 추가 및 저장소 계층 전환
- 기존 `PhotoCacheStoreProtocol` 계약을 GRDB 구현체로 대체
- 키워드 분석 서비스(Vision 기반) 추가
- 키워드 필터 UI(`AllPhotosView`) + 요약 카드 UI(`DashboardView`) 추가
- 로케일 기반 표시 언어(자동) 적용
- 테스트 추가 및 기존 테스트 보정

### 3.2 Out of Scope
- 자연어 검색
- 수동 언어 선택 UI
- 키워드 자동 삭제/자동 정리
- 동영상 프레임 분석

---

## 4. 설계 원칙 (TDD/DDD/OOP/Factory/Pure DI 반영)

### 4.1 TDD 원칙
- Red -> Green -> Refactor 순서를 강제한다.
- 기능 추가/변경은 항상 실패 테스트(RED)부터 시작한다.
- 한 번에 하나의 이유로만 테스트를 실패시키고, 최소 코드로 통과시킨다.
- 리팩토링은 테스트 통과 상태에서만 수행한다.

### 4.2 DDD 원칙
- 도메인 경계를 명확히 분리한다.
  - `Issue Detection` (기존 문제 감지)
  - `Keyword Analysis` (키워드 추출/정책)
  - `Photo Catalog Persistence` (GRDB 저장/조회)
- 유비쿼터스 언어를 문서/코드/테스트에서 통일한다.
  - `Keyword`, `ConfidenceThreshold`, `LocalizedKeyword`, `KeywordSummary`
- 도메인 규칙(예: confidence >= 0.8, 상위 3개 제한)은 서비스 내부 불변식으로 관리한다.

### 4.3 OOP 원칙
- 객체는 단일 책임을 갖게 분리한다.
  - `PhotoKeywordAnalyzer`: 키워드 추출/정규화
  - `KeywordLocalizationService`: 로케일 기반 표시 변환
  - `GRDBPhotoStore`: 저장소 책임
- 상위 계층은 구현이 아닌 인터페이스(프로토콜)에 의존한다.
- 데이터 구조 노출보다 행위를 우선한다(캡슐화).

### 4.4 Kent Beck Tidy First 원칙
- 구조 변경(Structural Change)과 동작 변경(Behavior Change)을 같은 커밋/PR에 섞지 않는다.
- 먼저 작은 정리(tidying)로 코드를 읽기/변경하기 쉽게 만든 뒤 기능 변경을 적용한다.
- tidying은 작고 되돌리기 쉬운 단위로 제한한다.
- 정리 변경은 가능한 한 별도 커밋(또는 별도 PR)로 분리한다.
- 탐색 과정에서 구조/동작 변경이 뒤섞였으면, 정리 커밋과 동작 커밋으로 다시 분해해 기록한다.

### 4.5 Factory 원칙
- 생성자 파라미터가 많거나 생성 순서/기본값 규칙이 있는 객체는 Factory로 캡슐화한다.
- Factory는 생성 책임만 가진다. 비즈니스 규칙은 도메인 서비스에 둔다.
- 테스트에서는 테스트용 Factory(또는 Builder)로 기본 fixture를 재사용한다.

### 4.6 Pure DI 원칙
- 의존성 조립은 앱 진입점(Composition Root)에서 수행한다.
- 기능 코드 내부에서 전역 싱글턴/Service Locator 조회를 금지한다.
- 하위 계층은 프로토콜에 의존하고, 구체 구현 선택은 상위(Composition Root)에서만 결정한다.

### 4.7 기존 계획과의 정합성
1. 기존 사용자 흐름 유지
- 스캔 진입점(`DashboardViewModel.startScan`)은 유지하고 내부 단계만 확장한다.

2. 변경 범위 최소화
- 기존 프로토콜/DTO를 최대 재사용하고 구현체만 SwiftData -> GRDB로 교체한다.

3. 단계적 전환
- 1차: GRDB 경로를 기본 경로로 만든다.
- 2차: SwiftData 의존 제거 및 레거시 코드 정리.

4. 검증 우선
- 단계별로 빌드/테스트를 통과한 뒤 다음 단계로 진행한다.

---

## 5. 작업 단계

### Phase 공통 적용 규칙 (TDD/DDD/OOP/Factory/Pure DI)
1. RED: 해당 Phase 목표를 검증하는 실패 테스트를 먼저 작성한다.
2. GREEN: 테스트를 통과하는 최소 구현만 추가한다.
3. REFACTOR: 중복 제거/책임 분리/명명 개선을 수행한다.
4. DDD 체크: 도메인 경계 침범 여부(서비스 간 책임 혼합)를 점검한다.
5. OOP 체크: 새 타입이 단일 책임을 가지는지, 프로토콜 경계가 유지되는지 점검한다.
6. Tidy First 체크: 구조 변경 커밋과 동작 변경 커밋이 분리되어 있는지 점검한다.
7. Factory 체크: 객체 생성 로직이 사용 로직에서 분리되어 있는지 점검한다.
8. Pure DI 체크: 의존성 조립이 Composition Root에만 있는지 점검한다.
9. 각 Phase 종료 전 `원칙 준수 게이트` 6개 항목을 모두 체크한다. 미적용 항목은 `N/A + 사유`를 남긴다.

### Phase 1. 저장소 기반 전환 준비

### 목표
GRDB를 도입할 수 있는 최소 기반을 만든다.

### 진행 현황 (2026-02-15)
- 상태: 완료
- 업데이트: GRDB 패키지 추가 및 저장소 중립 계약(`PhotoCacheStoreContract`) 분리/적용 완료.
- 검증: `./scripts/build-check.sh test` 통과 (`passed_tests: 137`, `errors: 0`).

### 변경 대상
- `PhotoCleaner.xcodeproj/project.pbxproj`
- `PhotoCleaner/Sources/SwiftData/PhotoCacheStore.swift` (타입/프로토콜 분리 준비)

### 작업
1. GRDB Swift Package를 프로젝트에 추가한다.
2. `PhotoCacheStoreProtocol`, DTO 타입(`CachedAssetDTO`, `CachedIssueDTO`, `ScanResultInfo` 등)을 저장소 중립 위치로 분리한다.
3. 기존 SwiftData 구현은 컴파일 유지 상태로 둔다(즉시 삭제 금지).
4. (TDD) 프로토콜 계약 테스트 초안을 먼저 작성해 구현체 전환 시 회귀 기준으로 고정한다.

### 검증
- `xcodebuild build -project PhotoCleaner.xcodeproj -scheme PhotoCleaner -destination 'generic/platform=iOS Simulator' 2>&1 | xcsift --warnings`

### 원칙 준수 게이트 (Phase 1 종료 조건)
- [ ] TDD: 저장소 프로토콜 계약 테스트를 RED->GREEN 순서로 작성/통과했다.
- [ ] DDD: `Persistence` 경계 밖(서비스/UI)으로 저장소 세부 구현이 새로 노출되지 않았다.
- [ ] OOP: 프로토콜/DTO의 책임이 분리되고 타입 책임이 단일하게 유지된다.
- [ ] Factory: 객체 생성 규칙이 필요한 경우 Factory로 분리했다. 미적용 시 `N/A` 사유를 기록했다.
- [ ] Pure DI: 의존성 조립이 기능 코드 내부가 아니라 진입점/조립 계층에 머무른다.
- [ ] Tidy First: 구조 정리 변경과 동작 변경을 분리 커밋/PR로 기록했다.

---

### Phase 2. GRDB 저장소 구현

### 목표
현재 SwiftData가 담당하던 저장소 기능을 GRDB 구현체로 대체 가능하게 만든다.

### 진행 현황 (2026-02-15)
- 상태: 진행 중
- 업데이트: `PhotoCacheStoreProtocol`에 키워드 저장/조회 계약(`AssetKeywordDTO`, `KeywordSummaryDTO`) 추가 완료.
- 업데이트: `GRDBPhotoStore` 및 `PhotoCacheStore(SwiftData)`에 키워드 저장/조회/요약 집계 구현 완료.
- 업데이트: 계약 테스트/Mock를 신규 계약에 맞게 보강 완료.
- 남은 작업: GRDB 전용 저장소 단위 테스트 보강 및 Phase 2 게이트 체크 정리.
- 검증: `./scripts/build-check.sh test` 통과 (`passed_tests: 138`, `errors: 0`, `warnings: 0`).

### 변경 대상
- `PhotoCleaner/Sources/Persistence/GRDB/DatabaseManager.swift` (신규)
- `PhotoCleaner/Sources/Persistence/GRDB/DatabaseMigrations.swift` (신규)
- `PhotoCleaner/Sources/Persistence/GRDB/GRDBPhotoStore.swift` (신규)

### 작업
1. DB 스키마 생성:
- `photo_assets`
- `photo_issues`
- `photo_keywords`
- `keyword_summary`
- `sync_metadata`
 - 진행 상태: 완료
2. 인덱스 생성:
- `idx_photo_issues_asset`
- `idx_photo_keywords_asset`
- `idx_photo_keywords_keyword`
 - 진행 상태: 완료
3. `PhotoCacheStoreProtocol`의 기존 메서드를 GRDB에서 동일하게 제공한다.
 - 진행 상태: 완료
4. 키워드 저장/조회용 메서드를 프로토콜에 추가한다.
 - 진행 상태: 완료
5. (TDD) 저장소 메서드별 실패 테스트를 먼저 작성한 뒤 CRUD를 구현한다.
 - 진행 상태: 완료 (`PhotoCacheStoreProtocolTests` 계약 테스트 및 `PhotoCleanerTests/GRDB/GRDBPhotoStoreTests.swift` 추가로 GRDB 전용 테스트 작성 완료, `./scripts/build-check.sh test` 통과)
6. (OOP) SQL 상세는 저장소 내부로 캡슐화하고 상위 계층에 쿼리 문자열을 노출하지 않는다.
 - 진행 상태: 진행 중 (GRDB 저장소 내부 캡슐화 완료, 키워드 도메인 적용 구간 추가 점검 예정)

### 검증
- 신규 저장소 단위 테스트 작성/통과
- 기존 `PhotoLibrarySyncService` 테스트가 GRDB 구현체/Mock 기반으로 통과
- 최신 실행: `./scripts/build-check.sh test` -> `passed_tests: 145`, `errors: 0`, `warnings: 0`, `failed_tests: 0` (2026-02-15)
- 작업 종료 시 자동 실행 규칙 반영 후 `./scripts/build-check.sh test` 결과로 GRDB 전용 테스트 포함 전체 통과 확인.
- 추가 반영: GRDB 전용 테스트 파일(`PhotoCleanerTests/GRDB/GRDBPhotoStoreTests.swift`)을 추가해 `Phase 2` 핵심 저장소 경로를 문서 기준으로 보강함.

### 원칙 준수 게이트 (Phase 2 종료 조건)
- [x] TDD: 저장소 CRUD/조회 메서드별 실패 테스트를 먼저 작성하고 통과했다.
- [ ] DDD: `Photo Catalog Persistence` 경계 안에서만 SQL/스키마 로직을 다룬다.
- [ ] OOP: `GRDBPhotoStore`가 저장 책임만 가지며 상위 계층은 프로토콜만 본다.
- [ ] Factory: DB/Store 생성 규칙은 생성 전용 객체(Factory/Builder)에 캡슐화했다.
- [ ] Pure DI: 구체 저장소 구현 선택은 Composition Root에서만 수행한다.
- [ ] Tidy First: 스키마 정리/리네이밍과 기능 동작 추가를 분리했다.

---

### Phase 3. 앱 부트스트랩 전환 (SwiftData 제거 시작)

### 목표
앱 실행 시 기본 저장소가 GRDB가 되도록 전환한다.

### 진행 현황 (2026-02-15)
- 상태: 진행 중
- 업데이트: `PhotoCleanerApp`에서 `ModelContainer` 제거 후 GRDB 스토어 기본 주입 경로 반영.
- 업데이트: `PhotoCleanerTests/GRDB/GRDBPhotoStoreTests.swift` 동기 생성자 반영에 맞춰 앱 시작 경로에서 GRDB 주입을 사용하도록 정렬.

### 변경 대상
- `PhotoCleaner/PhotoCleanerApp.swift`
- `PhotoCleaner/Sources/ViewModels/DashboardViewModel.swift`

### 작업
1. `PhotoCleanerApp`에서 `ModelContainer` 초기화를 제거한다.
 - 진행 상태: 완료
2. `GRDBPhotoStore`를 생성해 `DashboardViewModel`에 주입한다.
 - 진행 상태: 완료
3. `DashboardViewModel`의 저장소 참조를 GRDB 구현체 기준으로 정리한다.
 - 진행 상태: 완료 (부트스트랩은 `PhotoCacheStoreProtocol` 기반 주입으로 통일)
4. SwiftData import가 필요 없는 파일에서 제거한다.
 - 진행 상태: 진행 중 (`PhotoCleanerApp`, `DashboardViewModel`에서 제거; SwiftData 구현/모델 정리는 Phase 7)
5. (DDD/OOP) ViewModel은 도메인 서비스/저장소 프로토콜에만 의존하도록 경계를 고정한다.
 - 진행 상태: 진행 중 (`DashboardViewModel`은 `PhotoCacheStoreProtocol` 주입을 사용)
6. (Factory/Pure DI) 앱 진입점에서 Factory를 통해 ViewModel/Service를 조립하고, 기능 코드에서 직접 생성/전역 조회를 금지한다.
 - 진행 상태: 완료 (`AppBootstrapFactory`로 `DashboardViewModel` 조립 분리)

### 검증
- 앱 런치 후 초기 동기화(`performInitialSync`) 정상 동작 (다음 단계에서 수동 확인 필요)
- 수동 스캔 1회 실행/완료 확인 (다음 단계에서 수동 확인 필요)
- 최신 실행: `./scripts/build-check.sh test` -> `passed_tests: 146`, `errors: 0`, `warnings: 0`, `failed_tests: 0` (2026-02-15)

### 원칙 준수 게이트 (Phase 3 종료 조건)
- [ ] TDD: 부트스트랩 전환 관련 통합 테스트(주입/초기 동기화)를 먼저 작성/통과했다.
- [ ] DDD: ViewModel은 도메인 서비스/저장소 프로토콜 경계만 의존한다.
- [ ] OOP: ViewModel은 상태 관리 책임만 가지고 조립 책임을 갖지 않는다.
- [x] Factory: ViewModel 생성은 `AppBootstrapFactory`로 분리되어 생성 중복이 감소했다.
- [x] Pure DI: `PhotoCleanerApp`에서 `AppBootstrapFactory`를 통해 의존성을 조립한다.
- [ ] Tidy First: import/구조 정리 커밋과 동작 전환 커밋을 분리했다.

---

### Phase 4. 키워드 분석 도메인 구현

### 목표
키워드 분석 정책(로케일 자동 언어/0.8 하한/상위 3개)을 코드로 확정한다.

### 진행 현황 (2026-02-15)
- 상태: 시작 전
- 업데이트: 없음

### 변경 대상
- `PhotoCleaner/Sources/Models/AppSettings.swift`
- `PhotoCleaner/Sources/Views/Settings/SettingsView.swift`
- `PhotoCleaner/Sources/Services/PhotoKeywordAnalyzer.swift` (신규)
- `PhotoCleaner/Sources/Services/PhotoScanService.swift`

### 작업
1. 설정 추가:
- `keywordAnalysisEnabled` (기본값 정의)
- `keywordConfidenceThreshold` (기본값 0.8)
2. `PhotoKeywordAnalyzer`를 추가해 Vision 결과를 정책에 맞게 정규화한다.
3. `PhotoScanService` 스캔 루프에 키워드 분석 단계를 추가한다.
4. 취소/부분결과 시 키워드 저장 일관성을 유지한다.
5. (TDD) `confidence >= 0.8`, 상위 3개 제한, 분석 Off 규칙을 실패 테스트로 먼저 고정한다.
6. (DDD) 키워드 규칙은 UI가 아닌 도메인 서비스(`PhotoKeywordAnalyzer`)에만 둔다.

### 검증
- 단위 테스트: confidence 필터, 상위 3개 제한, 분석 On/Off
- 회귀 테스트: 기존 이슈 감지 결과 변화 없음

### 원칙 준수 게이트 (Phase 4 종료 조건)
- [ ] TDD: `confidence >= 0.8`, 상위 3개, 분석 Off 규칙을 테스트 먼저 고정했다.
- [ ] DDD: 키워드 정책 불변식은 `PhotoKeywordAnalyzer` 도메인 계층에만 존재한다.
- [ ] OOP: 분석/정책/저장 책임이 분리되어 각 객체의 역할이 명확하다.
- [ ] Factory: Analyzer 생성 설정(임계값/옵션) 조립은 생성 계층으로 분리했다.
- [ ] Pure DI: Analyzer/저장소 의존성은 생성자 주입으로 연결한다.
- [ ] Tidy First: 정책 리팩토링과 기능 추가를 분리 커밋으로 관리했다.

---

### Phase 5. 키워드 표시 언어 (로케일 자동)

### 목표
디바이스 로케일 기반으로 키워드 표시 언어를 자동 결정한다.

### 진행 현황 (2026-02-15)
- 상태: 시작 전
- 업데이트: 없음

### 변경 대상
- `PhotoCleaner/Sources/Services/KeywordLocalizationService.swift` (신규)
- `PhotoCleaner/Sources/Views/AllPhotos/AllPhotosView.swift`
- `PhotoCleaner/Sources/ViewModels/DashboardViewModel.swift`

### 작업
1. 로케일 판단 규칙을 정의한다 (`Locale.current` 기반).
2. 1차 한국어 매핑 테이블(핵심 키워드) + 미매핑 fallback(원문)을 적용한다.
3. 키워드 표시 텍스트와 내부 저장 키워드(원문)를 분리한다.
4. (TDD) 로케일별 변환 규칙(ko/en/fallback)을 케이스 기반 테스트로 선행한다.

### 검증
- 로케일별 단위 테스트(ko, en)
- 미매핑 키워드 fallback 테스트

### 원칙 준수 게이트 (Phase 5 종료 조건)
- [ ] TDD: 로케일 변환 규칙 테스트를 먼저 작성하고 구현했다.
- [ ] DDD: `LocalizedKeyword` 표현 규칙은 localization 도메인으로 한정된다.
- [ ] OOP: `KeywordLocalizationService`는 표시 변환 책임만 가진다.
- [ ] Factory: 로케일 전략 생성이 필요하면 전략 Factory를 사용한다. 미적용 시 `N/A` 기록.
- [ ] Pure DI: 로케일 서비스 주입은 Composition Root/Factory에서 수행한다.
- [ ] Tidy First: 키워드 문자열 정리와 동작 변경을 분리했다.

---

### Phase 6. UI 구현 (전체 사진 + 대시보드)

### 목표
사용자 노출 요구사항을 충족하는 키워드 UI를 완성한다.

### 진행 현황 (2026-02-15)
- 상태: 시작 전
- 업데이트: 없음

### 변경 대상
- `PhotoCleaner/Sources/Views/AllPhotos/AllPhotosView.swift`
- `PhotoCleaner/Sources/Views/Dashboard/DashboardView.swift`
- `PhotoCleaner/Sources/ViewModels/DashboardViewModel.swift`
- `PhotoCleaner/Sources/Views/Components/Cards/KeywordSummaryCard.swift` (신규)

### 작업
1. `AllPhotosView`에 키워드 칩 필터 영역을 추가한다.
2. 선택 키워드 기준으로 표시 사진을 필터링한다.
3. `DashboardView`에 키워드 요약 카드(분석 사진 수 + 상위 키워드 N개)를 추가한다.
4. 카드 탭 시 키워드 필터 화면으로 이동시킨다.
5. (OOP) 필터링 계산은 ViewModel/도메인으로 두고 View는 렌더링 책임만 갖게 한다.

### 검증
- 수동 QA: 필터 선택/해제, 빈 상태, 스캔 중/완료 후 갱신
- 프리뷰/기본 화면 빌드 확인

### 원칙 준수 게이트 (Phase 6 종료 조건)
- [ ] TDD: 필터/카드 동작 테스트(또는 ViewModel 테스트)를 먼저 작성/통과했다.
- [ ] DDD: View는 렌더링만 담당하고 도메인 규칙은 ViewModel/Service가 담당한다.
- [ ] OOP: UI 컴포넌트(`KeywordSummaryCard`)는 표시 책임만 가진다.
- [ ] Factory: 화면 조립 시 생성 규칙이 복잡하면 ViewModel Factory를 사용한다.
- [ ] Pure DI: UI 계층은 주입된 의존성만 사용하고 전역 조회를 하지 않는다.
- [ ] Tidy First: UI 구조 정리(레이아웃/리네이밍)와 동작 추가를 분리했다.

---

### Phase 7. 마이그레이션 및 레거시 정리

### 목표
SwiftData 의존을 제거하고 GRDB 단일 저장소 상태를 완료한다.

### 진행 현황 (2026-02-15)
- 상태: 시작 전
- 업데이트: 없음

### 변경 대상
- `PhotoCleaner/Sources/SwiftData/*` (삭제 또는 전환용 최소 코드만 유지)
- `PhotoCleanerTests/SwiftData/*` (GRDB 기준으로 대체)

### 작업
1. SwiftData 잔존 참조를 제거한다.
2. 테스트 디렉터리를 저장소 기술 중립 네이밍으로 재구성한다.
3. 필요 시 1회성 데이터 마이그레이션 도구를 추가한다.
4. (DDD) 마이그레이션 중에도 도메인 규칙(`confidence`, `keyword summary`) 불변식이 유지되는지 검증한다.

### 검증
- `rg -n "SwiftData|ModelContainer|@Model" PhotoCleaner PhotoCleanerTests` 결과가 의도된 파일만 남는지 확인
- 전체 테스트 통과

### 원칙 준수 게이트 (Phase 7 종료 조건)
- [ ] TDD: 마이그레이션/회귀 테스트를 먼저 작성하고 데이터 일관성을 검증했다.
- [ ] DDD: 마이그레이션 이후에도 도메인 불변식(`confidence`, `keyword summary`)이 유지된다.
- [ ] OOP: 레거시 제거 후에도 각 객체 책임이 단일하게 유지된다.
- [ ] Factory: 남은 생성 경로가 Factory/Composition Root로 정리됐다.
- [ ] Pure DI: Service Locator/전역 싱글턴 의존이 제거되었음을 확인했다.
- [ ] Tidy First: 레거시 정리 커밋과 기능 동작 변경 커밋을 분리했다.

---

## 6. 테스트 계획

### 6.1 단위 테스트
- 키워드 정책: confidence 0.8, 상위 3개 제한
- 로케일 매핑: ko/en/fallback
- GRDB Repository CRUD 및 쿼리 테스트

### 6.2 통합 테스트
- 사진 동기화 -> 스캔 -> GRDB 저장 -> 대시보드/전체 사진 반영
- 스캔 취소 -> 부분 결과 반영

### 6.3 회귀 테스트
- 기존 이슈 타입 스캔 회귀
- 중복 스캔 기능 회귀

### 6.4 실행 명령
- `./scripts/build-check.sh`
- `./scripts/build-check.sh test`
- `xcodebuild test -project PhotoCleaner.xcodeproj -scheme PhotoCleaner -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | xcsift`

### 6.5 TDD 실행 체크리스트
- RED 단계 커밋: 실패 테스트만 포함됐는지 확인
- GREEN 단계 커밋: 테스트 통과를 위한 최소 코드인지 확인
- REFACTOR 단계 커밋: 동작 변경 없이 구조 개선만 했는지 확인
- 각 단계마다 테스트 전체 재실행

---

## 7. PR 분할 계획 (권장)

1. PR-1: GRDB 의존성 + 저장소 프로토콜 분리 + 기본 스키마
2. PR-2: GRDBPhotoStore 구현 + App 부트스트랩 전환
3. PR-3: 키워드 분석 서비스 + 스캔 파이프라인 통합
4. PR-4: AllPhotos/Dashboard UI + 로케일 자동 표시
5. PR-5: SwiftData 제거 + 테스트 정리 + 문서 업데이트

각 PR 머지 기준:
- 빌드 통과
- 신규 테스트 포함
- 회귀 없음
- Tidy First 원칙 준수:
  - 구조 정리 PR(또는 커밋)과 기능 동작 변경 PR(또는 커밋)을 분리
  - 혼합 변경 PR 금지

---

## 8. 주요 리스크와 대응

1. 리스크: 저장소 전환 중 데이터 불일치
- 대응: 프로토콜 계약 테스트 + 통합 테스트로 스캔/조회 일치 검증

2. 리스크: 키워드 분석으로 스캔 시간이 증가
- 대응: 썸네일 기반 분석 유지, 취소 가능성 보장, 성능 측정 지표 기록

3. 리스크: 로케일 번역 품질 편차
- 대응: 핵심 키워드 우선 매핑 + 미매핑 fallback 원칙 유지

4. 리스크: 대량 사진 필터에서 UI 지연
- 대응: 키워드별 asset identifier 조회 결과 캐싱, 메인스레드 연산 최소화

---

## 9. 오픈 이슈 (구현 전 확정 권장)

1. `keywordAnalysisEnabled` 기본값을 `true`로 할지 `false`로 할지
2. 기존 SwiftData 데이터를 실제 앱에서 보존할지(무손실 마이그레이션 필요 여부)
3. 키워드 요약 카드의 상위 키워드 노출 개수(N)를 3/5 중 무엇으로 고정할지

---

## 10. 조사 근거 (TDD/DDD/OOP/Factory/Pure DI)

- TDD Red-Green-Refactor: [Test-Driven Development (Martin Fowler)](https://martinfowler.com/bliki/TestDrivenDevelopment.html)
- DDD Ubiquitous Language: [Ubiquitous Language (Martin Fowler)](https://martinfowler.com/bliki/UbiquitousLanguage.html)
- DDD Bounded Context: [Bounded Context (Martin Fowler)](https://martinfowler.com/bliki/BoundedContext.html)
- DDD 핵심 요약(Reference): [DDD_Reference_201503-2.pdf (Eric Evans)](https://www.domainlanguage.com/wp-content/uploads/2016/05/DDD_Reference_201503-2.pdf)
- OOP 핵심 개념(객체/클래스/캡슐화/상속/인터페이스): [Object-Oriented Programming Concepts (Oracle Java Tutorials)](https://docs.oracle.com/javase/tutorial/java/concepts/)
- Factory Method 패턴: [Factory Method (Refactoring.Guru)](https://refactoring.guru/design-patterns/factory-method)
- DI / Composition Root: [Inversion of Control Containers and the Dependency Injection pattern (Martin Fowler)](https://martinfowler.com/articles/injection.html)
- Pure DI 개념 정리: [Dependency Injection in .NET - Composition Root](https://learn.microsoft.com/en-us/dotnet/core/extensions/dependency-injection-guidelines)
- Tidy First 도서 페이지: [Tidy First? (Kent Beck, O'Reilly)](https://www.oreilly.com/library/view/tidy-first/9781098151232/)
- Tidy First 분리 원칙(Separate Tidying): [Chapter 16. Separate Tidying](https://www.oreilly.com/library/view/tidy-first/9781098151232/ch16.html)
- Tidy First 인터뷰 보강: [SE Radio 615: Kent Beck on Tidy First?](https://se-radio.net/2024/05/se-radio-615-kent-beck-on-tidy-first/)

---
