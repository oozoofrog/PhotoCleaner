# PhotoCleaner 사진 키워드 분석 기능 기획서 (Draft v0.3)

## 0. 문서 상태

| 항목 | 내용 |
|-----|------|
| 작성일 | 2026-02-14 |
| 상태 | Draft (결정 1/2/3/4/5 반영 완료) |
| 대상 브랜치 | `feature/photo-keyword-analysis` |
| 목적 | 사진 내용 기반 키워드 분석 기능의 MVP 범위 확정 |

---

## 1. 배경

현재 PhotoCleaner는 `다운로드 실패 / 손상 / 스크린샷 / 대용량 / 중복` 중심으로 "문제 사진 정리"를 지원한다.  
새 기능은 문제 감지와 별개로, **사진 내용을 키워드로 분석해 빠르게 찾고 정리하는 보조 기능**을 추가하는 것이 목표다.

---

## 2. 가정 (명시)

1. 분석은 온디바이스에서 수행한다. (서버 업로드 없음)
2. 기존 스캔 흐름(`PhotoScanService` 스트리밍)을 재사용한다.
3. MVP에서는 키워드 기반 자동 삭제/추천 삭제는 제공하지 않는다.
4. 키워드 결과는 재스캔 비용 절감을 위해 로컬 캐시에 저장한다.
5. 기존 핵심 기능(중복, 대용량, 스크린샷) 성능 저하가 체감되지 않아야 한다.

추가 가정:
6. "현재 국가 기반"은 **디바이스 Region/Locale 기반 키워드 표시 언어 선택**으로 해석한다.
7. 저장 모델은 SQLite(GRDB) 단일 저장소로 통합한다. (기존 SwiftData 저장소는 단계적으로 전환)

---

## 3. 목표/비목표

### 3.1 목표 (MVP)
- 사진 1장 단위로 내용 기반 키워드 태깅
- 사용자가 키워드로 사진을 필터링해 빠르게 탐색
- 분석 진행 상태를 사용자에게 명확히 표시

### 3.2 비목표 (MVP 제외)
- 자연어 검색(예: "작년 제주도 바다 사진 보여줘")
- 사용자 정의 사전/동의어 편집
- 클라우드 동기화
- 키워드 기반 자동 정리(자동 삭제/자동 보관)

---

## 4. 사용자 시나리오

1. 사용자가 설정에서 "키워드 분석"을 켠다.
2. 사용자가 전체 검사 또는 키워드 분석 실행을 시작한다.
3. 앱이 사진별 키워드를 추출하고 진행률을 표시한다.
4. 사용자가 전체 사진 화면에서 키워드 필터(예: 사람, 문서, 음식)를 선택한다.
5. 선택 키워드에 해당하는 사진만 확인 후 수동 정리한다.

---

## 5. 기능 요구사항 (MVP)

### 5.1 분석
- 각 사진에서 키워드 후보를 추출한다.
- 키워드는 신뢰도(confidence) 기준 이상만 저장한다.
- 사진당 저장 키워드 수를 제한한다. (초기: 최대 3개)

### 5.2 결과 노출
- `AllPhotosView`에서 키워드 필터 UI 제공
- 키워드 선택 시 해당 사진만 그리드에 표시
- 필터 해제 시 전체 사진 복귀
- `DashboardView`에 키워드 분석 요약 카드 추가 (상위 키워드/분석 완료 사진 수)

### 5.3 설정
- 키워드 분석 On/Off 토글
- 최소 신뢰도 옵션 (예: 0.5 / 0.8 / 0.9)

### 5.4 진행 상태
- 스캔 중 키워드 분석 단계 표시
- 취소 시 부분 결과 유지

---

## 6. 기술 설계 초안 (현재 코드 기준)

### 6.1 연동 지점
- 스캔 파이프라인: `PhotoCleaner/Sources/Services/PhotoScanService.swift`
- 이미지 요청: `PhotoCleaner/Sources/Services/PhotoAssetService.swift`
- 설정 저장: `PhotoCleaner/Sources/Models/AppSettings.swift`
- 대시보드 노출: `PhotoCleaner/Sources/ViewModels/DashboardViewModel.swift`, `PhotoCleaner/Sources/Views/Dashboard/DashboardView.swift`
- 저장소(전환): SQLite + GRDB 레이어 (스캔 결과/키워드 포함 단일 저장소)
- 결과 UI: `PhotoCleaner/Sources/Views/AllPhotos/AllPhotosView.swift`

### 6.2 처리 흐름
1. 스캔 대상 사진 썸네일 로드 (`requestThumbnailCGImageForVision` 재사용)
2. Vision 기반 분류로 키워드 후보 + confidence 획득
3. 임계값/최대 개수 정책 적용
4. SQLite(GRDB) 단일 저장소에 결과 저장 (asset/issue/keyword)
5. 화면 필터에서 사용
6. 대시보드 요약 카드 집계 반영

### 6.3 데이터 모델 방향
- 확정: 모든 저장소는 SQLite(GRDB)로 통합
- 제안 테이블(초안):
  - `photo_assets(asset_id TEXT PRIMARY KEY, created_at INTEGER, width INTEGER, height INTEGER, scan_status TEXT, updated_at INTEGER)`
  - `photo_issues(id INTEGER PRIMARY KEY AUTOINCREMENT, asset_id TEXT, issue_type TEXT, severity INTEGER, detected_at INTEGER)`
  - `photo_keywords(asset_id TEXT, keyword TEXT, confidence REAL, analyzed_at INTEGER)`
  - `keyword_summary(keyword TEXT PRIMARY KEY, photo_count INTEGER, updated_at INTEGER)`
- 인덱스(초안):
  - `INDEX idx_photo_issues_asset ON photo_issues(asset_id)`
  - `INDEX idx_photo_keywords_asset ON photo_keywords(asset_id)`
  - `INDEX idx_photo_keywords_keyword ON photo_keywords(keyword)`

트레이드오프:
- 장점: 키워드 필터/집계 쿼리가 단순하고 빠름
- 단점: 기존 SwiftData 데이터 마이그레이션/전환 작업이 필요

---

## 7. UX 초안

### 7.1 설정 화면
- "키워드 분석" 토글
- "최소 신뢰도" Picker
- "표시 언어"는 현재 국가(Region/Locale) 기반 자동 선택 (수동 선택은 추후 검토)

### 7.2 전체 사진 화면
- 상단 또는 헤더 영역에 키워드 칩 필터
- 선택된 키워드 칩 강조
- "전체" 칩으로 빠른 해제

### 7.3 대시보드 화면
- 키워드 분석 요약 카드 표시
- 카드 정보: 분석 완료 사진 수, 상위 키워드 N개
- 카드 탭 시 키워드 필터 화면으로 이동
### 7.4 빈 상태
- 분석 결과가 없으면
  - "키워드 분석을 실행해 주세요" 메시지 노출

---

## 8. 성능/품질 기준 (MVP)

1. 메모리 폭증 없이 대량 사진 처리 가능해야 함
2. 스캔 취소/재시작 시 UI 멈춤이 없어야 함
3. 기존 문제 감지 기능 정확도에 영향이 없어야 함
4. 키워드 노이즈를 줄이기 위해 confidence 하한 적용

---

## 9. 테스트 기준

### 9.1 단위 테스트
- 신뢰도 필터링 로직 검증
- 사진당 최대 키워드 수 제한 검증
- 설정값 변경 시 분석 정책 반영 검증

### 9.2 통합 테스트
- 스캔 → GRDB 저장 → 필터 표시까지 연결 검증
- 스캔 → GRDB 저장 → 대시보드 요약 카드 표시 연결 검증
- 분석 Off 상태에서 기존 스캔이 동일 동작하는지 검증

### 9.3 회귀 테스트
- 기존 `IssueType` 기반 카드/목록 기능 회귀 없음 확인
- 스캔 취소/부분 결과 동작 회귀 없음 확인

---

## 10. 결정 반영 (2026-02-14)

1. 키워드 결과 노출 1순위 화면
- 확정: B (`AllPhotosView` + 대시보드 요약 카드)

2. 키워드 언어 정책
- 확정: 현재 국가 기반 (Region/Locale 기반 표시 언어 선택으로 해석)

3. 저장 모델
- 확정: 모든 저장소를 SQLite(GRDB)로 통합

4. 기본 confidence
- 확정: 0.8 (초기 기본값)

5. 1차 릴리즈 범위
- 확정: A (사진만)

---

## 11. 기본 confidence 설명

| 값 | 장점 | 단점 | 적합한 경우 |
|---|---|---|---|
| 0.5 | 키워드 누락이 적음 | 틀린 키워드 노출 증가 | 탐색 폭을 넓게 보고 싶을 때 |
| 0.8 | 노이즈를 줄이면서 탐색성 유지 | 0.5 대비 일부 키워드 누락 가능 | MVP 기본값으로 균형형 |
| 0.9 | 오탐이 적음 | 키워드 누락이 많아짐 | 매우 보수적인 결과가 필요할 때 |

운영 제안:
1. MVP 기본값은 `0.8`
2. 사용자 설정에서만 상향/하향 조정
3. 사진당 상위 3개 키워드 제한은 유지

---

## 12. 1차 구현 체크리스트

- [ ] 설정 모델에 키워드 분석 옵션 추가
- [ ] 스캔 서비스에 키워드 분석 단계 추가
- [ ] GRDB 스키마/저장소 구현 (asset/issue/keyword)
- [ ] 기존 SwiftData 저장소에서 GRDB로 전환 전략 수립/적용
- [ ] 전체 사진 화면 필터 UI 추가
- [ ] 대시보드 키워드 요약 카드 추가
- [ ] 단위/통합 테스트 추가
- [ ] 회귀 테스트 통과
