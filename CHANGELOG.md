# Changelog

## v1.1.2 (2026-03-25) — dev 산출물 브랜치별 분리 + test 스킬 Spring 전용화

### Fixes
- **dev 산출물 경로 분리**: `.dev/` → `.dev/{branch-slug}/` 브랜치별 폴더로 변경하여 기능별 개발 과정 보존
- **DEV_DIR 변수 도입**: 모든 Phase·스킬에서 일관된 산출물 경로 참조
- **--phase 단독 실행 버그**: implement/review/complete 단독 실행 시 DEV_DIR 미정의 수정
- **pull-request pr-context 탐색**: glob 패턴 대신 정확한 DEV_DIR 계산으로 변경

### Enhancements
- **test 스킬 Spring 전용 가드**: `java-spring`/`kotlin-gradle` 이외 프로젝트에서 안내 후 종료

## v1.1.1 (2026-03-21) — test 스킬 추가

### Features
- **test**: 도메인별 단위/통합/E2E 테스트 자동 작성 스킬 추가
  - 기존 테스트 구조·스타일 분석 후 동일 패턴으로 생성
  - PRD 수용 기준(AC) 기반 테스트 케이스 자동 도출
  - 커버리지 목표 설정 및 검증 (`--coverage N`)
  - `--type unit|integration|e2e|all` 옵션으로 유형 선택
- **dev 파이프라인 연동**: complete 단계에 테스트 작성(Step 1) 추가 — 구현 → 리뷰 → 테스트 → 커밋 → PR
- **자연어 트리거**: "테스트 작성해줘", "테스트 추가해줘" 등으로 호출 가능

## v1.0.1 (2026-03-21) — 스킬 호출 안정성 개선

### Fixes
- **dev phase-complete**: `Read()` 기반 스킬 실행을 `Skill` 도구 호출로 변경하여 allowed-tools 제한이 시스템 레벨에서 강제되도록 수정
- **스킬 교차 참조**: 모든 스킬 간 참조에 `ttutak:` prefix 적용하여 다른 플러그인과의 이름 충돌 방지
- **pull-request**: dev 파이프라인 컨텍스트 연동을 `.dev/pr-context.md` 파일 기반으로 재설계

### Enhancements
- **자연어 스킬 라우팅**: dev, context, lens 스킬의 자연어 트리거 추가

## v1.0.0 (2026-03-21) — 첫 정식 릴리즈

첫 정식 릴리즈. 8개 스킬 + 9개 에이전트 팀 기반 개발 자동화 플러그인.

### Features
- **dev**: PRD → 설계 → 구현 → 리뷰 → PR 전체 개발 사이클 자동화
- **context**: 도메인 지식 등록 및 관리
- **commit**: 브랜치 타입 기반 한국어 커밋 메시지 자동 생성
- **pull-request**: 커밋 히스토리 기반 PR 제목/본문 자동 생성
- **lens**: 코드 정책 분석 및 PO/PD 친화적 보고서
- **humanizer**: AI 글쓰기 패턴 감지 및 교정
- **research**: 웹 검색/문서 분석 기반 도메인 리서치
- **setup**: 프로젝트 초기 설정 자동화
- **references/**: 외부 규격 참조 기능
- **coder 배치 병렬화**: 독립적 구현 단계 병렬 처리
- **Slack 알림**: PR 생성 시 Slack 채널 자동 알림
