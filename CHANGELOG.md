# Changelog

## v1.3.0 (2026-05-04) — cross-review 스킬 추가

### Features
- **cross-review**: dev 산출물(PRD/설계서/Trust Ledger) 기반 교차 검증 리뷰 스킬 추가
  - codex / claude 두 advisor 경로 지원 (선택 가능)
  - codex 경로: codex CLI + companion 스크립트로 다른 모델 관점의 교차 검증
  - claude 경로: qa-manager + security-auditor 병렬 호출 (cross-review 미션 contract)
  - 검증 미션: AC 충족 매트릭스 / 설계 범위 이탈 / 신규 위험 / references 위반
  - trust-ledger·self-check 기반 중복 보고 차단
  - 산출물 부재 시 fallback 모드 (일반 리뷰)
  - 발견 항목 일괄 처리 (전부/일부/직접 입력/건너뛰기)
  - 자동 수정 금지, 모든 수정은 사용자 승인 후 coder 위임

## v1.2.1 (2026-04-22) — 워크플로우 견고화 + 릴리스 자동화

### Fixes
- **훅 false positive/negative 제거**: `pre-tool-guard.sh`를 `jq` 기반 명령 추출 + 단어 경계 regex로 재작성하여 `git commitstats` 같은 substring 매칭 제거. `symbolic-ref` 실패 시 `rev-parse --verify HEAD`로 detached HEAD를 감지해 가드 우회 차단
- **훅 중복 실행 제거**: `settings.json`과 `plugin.json`에 중복 등록되어 있던 훅을 `plugin.json` 한 곳으로 통일
- **파이프라인 state 무결성**: `phase-setup` 재개 시 state.md의 브랜치/HEAD와 현재 상태를 비교해 외부 개입을 감지. state.md에 `last-known-head` 필드 추가
- **phase-review diff 공백 안전장치**: 사용자가 파이프라인 도중 수동 커밋을 끼워 넣어 `git diff --cached`가 비는 경우 브랜치 비교 diff로 전환하는 옵션 제공
- **phase-setup stash 자동 보호**: 베이스 브랜치 `checkout` / `pull` 전 미커밋 변경을 자동 stash하고 작업 브랜치 전환 후 복원. conflict 발생 시 사용자에게 선택 제시
- **config.json 부재 가드**: `commit` / `dev` 진입부에 `.claude/config.json` 존재 검증을 추가하여 조용한 기본값 동작을 차단. `setup` 스킬이 최초 실행 시 템플릿을 자동 복사하도록 개선
- **민감 파일 패턴 정확도**: `*secret*`, `credentials*` 같은 광범위 glob을 앵커된 패턴(`.env`, `.env.*`, `*.secret`, `credentials.json` 등)으로 교체하여 `secretary.md` 같은 무관한 파일의 false positive 제거
- **릴리스 버전 불일치 감지**: `release.yml`에 `plugin.json` / `marketplace.json` / `CHANGELOG.md` 세 곳의 버전 일치 검증 step 추가. 불일치 시 릴리스 생성 실패

### Enhancements
- **Hotfix 경량 보안 감사**: `--hotfix` 모드에 phase-implement 자기점검 이후 security-auditor 호출 단계 추가 (CRITICAL/HIGH만 보고). 결과를 Trust Ledger `### Hotfix 긴급 감사` 섹션에 기록하고 PR 본문의 Audit Summary에 반영
- **`tools/bump-version.sh`**: `plugin.json` / `marketplace.json` 버전 일괄 갱신 스크립트 추가. SemVer 검증 및 CHANGELOG 섹션 유무 경고 포함
- **`tools/test-pre-tool-guard.sh`**: pre-tool-guard 훅 단위 테스트(14개 케이스, 복합 명령 우회 검증 포함) 추가

## v1.2.0 (2026-03-29) — tech-debt 스킬 추가 + test 호출 위치 개선

### Features
- **tech-debt**: 코드베이스 기술 부채 분석 스킬 추가
  - 코드/아키텍처/의존성/테스트 4가지 유형별 부채 감지
  - Health Score (100점 만점, A~F 등급) 산출
  - 심각도 × 수정 용이성 × 영향 범위 기반 우선순위 로드맵
  - Java/Kotlin, Node, Python 의존성 분석 + 범용 모드
  - context/ 연동으로 의도된 아키텍처 vs 실제 구조 비교
  - 읽기 전용, 프로젝트 타입 무관

## v1.1.3 (2026-03-29) — test 스킬 호출 위치 개선

### Fixes
- **dev 파이프라인 test 호출 위치 이동**: phase-complete → phase-implement로 이동하여 리뷰가 테스트 코드까지 포함하도록 개선
- **자기점검 후 테스트 작성**: 자기점검으로 Critical 수정 완료 후 깨끗한 코드 기준으로 테스트 작성
- **state.md 추적**: implement 단계에 자기점검/테스트 작성 항목 추가, --resume 호환

## v1.1.2 (2026-03-25) — dev 산출물 브랜치별 분리 + test 스킬 Spring 전용화

### Fixes
- **dev 산출물 경로 분리**: `.dev/` → `.dev/{branch-slug}/` 브랜치별 폴더로 변경하여 기능별 개발 과정 보존
- **DEV_DIR 변수 도입**: 모든 Phase·스킬에서 일관된 산출물 경로 참조
- **--phase 단독 실행 버그**: implement/review/complete 단독 실행 시 DEV_DIR 미정의 수정
- **pull-request pr-context 탐색**: glob 패턴 대신 정확한 DEV_DIR 계산으로 변경

### Enhancements
- **test 스킬 Spring 전용 가드**: `java-spring`/`kotlin-gradle` 이외 프로젝트에서 안내 후 종료
- **research 스킬 인터뷰 질문**: 번호 선택지를 AskUserQuestion 구조화 형식으로 변환
- **히어로 설명 문구 개선**: README 및 index.html의 소개 문구 업데이트

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
