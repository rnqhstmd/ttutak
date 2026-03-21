---
name: test
version: 1.0.0
description: 도메인별 단위/통합/E2E 테스트를 작성하고 커버리지를 검증한다
argument-hint: "[도메인] [--type unit|integration|e2e|all] [--coverage 80]"
allowed-tools:
  # 파일 탐색/읽기
  - Read
  - Glob
  - Grep
  - Edit
  - Write
  # 빌드/테스트 실행
  - Bash(./gradlew:*)
  - Bash(npm:*)
  - Bash(bun:*)
  - Bash(npx:*)
  - Bash(pytest:*)
  - Bash(python:*)
  # 유틸
  - Bash(git diff:*)
  - Bash(git log:*)
  - Bash(git status:*)
  - Bash(git rev-parse:*)
  - Bash(git branch:*)
  - Bash(which:*)
  - Bash(test:*)
  - Bash(find:*)
  - Bash(ls:*)
  - Bash(cat:*)
  - Bash(wc:*)
  - Task
  - AskUserQuestion
---

도메인별로 단위/통합/E2E 테스트를 분석·작성하고, 커버리지 기준을 검증한다.

항상 한국어로 응답한다.

## 인자

- `ARGS[0]` (optional): 도메인명 또는 자연어 요청. 미지정 시 변경된 코드 기반으로 자동 감지.
- `--type unit|integration|e2e|all` (optional): 작성할 테스트 유형. 기본값 `all`.
- `--coverage N` (optional): 목표 커버리지 퍼센트. 기본값 `80`.

### 의도 파싱

ARGS를 파싱하여 아래 변수를 결정한다:

| 변수 | 결정 방법 |
|------|----------|
| `TARGET_DOMAIN` | ARGS[0]에서 도메인명 추출. 없으면 자동 감지 |
| `TEST_TYPE` | `--type` 값. 기본값 `all` |
| `COVERAGE_TARGET` | `--coverage` 값. 기본값 `80` |

## Step 0: 환경 감지

### 0-1: 프로젝트 루트 및 타입

1. `git rev-parse --show-toplevel`로 프로젝트 루트 확인.
2. `.claude/config.json`의 `projectTypes`에서 프로젝트 타입을 감지한다.

### 0-2: 테스트 프레임워크 감지

프로젝트 타입별로 테스트 프레임워크와 디렉토리를 감지한다:

| 프로젝트 타입 | 감지 파일 | 프레임워크 | 테스트 루트 |
|--------------|----------|-----------|-----------|
| java-spring | `build.gradle.kts` 또는 `build.gradle` | JUnit 5 | `src/test/` |
| node | `package.json` | Jest 또는 Vitest (`devDependencies` 확인) | `__tests__/` 또는 `*.test.ts` |
| python | `pyproject.toml` 또는 `setup.py` | pytest | `tests/` |

감지 불가 시 AskUserQuestion으로 사용자에게 테스트 프레임워크와 디렉토리를 입력받는다.

### 0-3: 기존 테스트 구조 분석

테스트 루트에서 기존 테스트 파일의 **네이밍 패턴과 디렉토리 구조**를 분석한다:

1. 테스트 파일을 Glob으로 탐색한다 (예: `src/test/**/*Test.java`, `**/*.test.ts`).
2. 파일명과 경로에서 패턴을 추출한다:
   - 단위 테스트: `{Class}Test`, `{Class}.test.ts`
   - 통합 테스트: `{Class}IntegrationTest`, `{Class}.integration.test.ts`
   - E2E 테스트: `{Class}E2ETest`, `{Class}.e2e.test.ts`
3. 디렉토리 구조에서 도메인별 분류 패턴을 파악한다:
   - 예: `domain/{도메인}/`, `infrastructure/{도메인}/`, `interfaces.api/{도메인}/`
4. 기존 테스트 2-3개를 Read하여 **코딩 스타일**을 파악한다:
   - import 스타일, assertion 라이브러리, 테스트 헬퍼/픽스처 사용 패턴
   - `@SpringBootTest`, `@DataJpaTest`, `@WebMvcTest` 등 어노테이션 패턴
   - 테스트 데이터 생성 방식 (Builder, Factory, Fixture)

이 분석 결과를 `TEST_CONVENTIONS`에 저장하여 이후 테스트 작성 시 일관성을 유지한다.

## Step 1: 대상 도메인 결정

### 도메인 자동 감지 (TARGET_DOMAIN 미지정 시)

1. **dev 파이프라인 컨텍스트 확인**: `.dev/prd.md`와 `.dev/design.md`가 존재하면 Read하여 대상 도메인과 수용 기준(AC)을 추출한다.
2. **변경 파일 기반 감지**: dev 컨텍스트가 없으면 최근 변경 파일에서 도메인을 추출한다:
   ```
   git diff main --name-only
   ```
   변경 파일의 경로에서 도메인 패키지/디렉토리를 식별한다.
3. **감지 불가 시**: AskUserQuestion으로 사용자에게 도메인을 입력받는다.

### 도메인 코드 수집

대상 도메인의 소스 코드를 수집한다:

1. **소스 파일 탐색**: 프로젝트 구조에서 도메인과 관련된 파일을 Glob/Grep으로 탐색한다.
2. **레이어별 분류**: 탐색된 파일을 레이어별로 분류한다:
   - **도메인 계층**: 엔티티, VO, 도메인 서비스, 리포지토리 인터페이스
   - **인프라 계층**: 리포지토리 구현, 외부 API 클라이언트, 캐시
   - **인터페이스 계층**: 컨트롤러, DTO, API 엔드포인트
3. 각 파일을 Read하여 테스트 작성에 필요한 정보를 확보한다.

## Step 2: 테스트 계획 수립

수집한 코드와 기존 테스트를 분석하여 테스트 계획을 수립한다.

### 2-1: 기존 커버리지 분석

1. 해당 도메인의 **기존 테스트 파일**을 탐색한다.
2. 소스 파일 대비 테스트가 존재하는 파일 목록을 파악한다.
3. 기존 테스트의 테스트 메서드를 분석하여 **이미 검증된 시나리오**를 파악한다.

### 2-2: 누락 테스트 도출

각 레이어별로 누락된 테스트를 도출한다:

**단위 테스트 (도메인 계층)**:
- 엔티티의 생성/검증 로직
- VO의 동등성, 불변성
- 도메인 서비스의 비즈니스 규칙
- 엣지 케이스: null, 빈 값, 경계값

**통합 테스트 (서비스/인프라 계층)**:
- 서비스 계층의 트랜잭션 동작
- 리포지토리의 쿼리 정확성
- 외부 연동 (캐시, 메시지 큐 등)

**E2E 테스트 (인터페이스 계층)**:
- API 엔드포인트의 요청/응답
- 인증/인가 검증
- 에러 응답 형식

### 2-3: dev 파이프라인 AC 연동

`.dev/prd.md`가 존재하면 수용 기준(AC)을 테스트 케이스로 변환한다:
- 각 AC를 검증하는 테스트가 이미 존재하는지 확인
- 누락된 AC에 대한 테스트를 계획에 추가

### 2-4: 계획 제시

사용자에게 테스트 계획을 제시한다:

```
## 테스트 계획: {도메인}

### 현황
- 소스 파일: N개
- 기존 테스트: N개 (커버리지 추정: ~N%)
- 목표 커버리지: {COVERAGE_TARGET}%

### 작성 예정

#### 단위 테스트 (N개)
| # | 테스트 클래스 | 검증 대상 | 테스트 케이스 수 |
|---|-------------|----------|---------------|
| 1 | {Entity}Test | 생성, 검증, 상태 변경 | N개 |

#### 통합 테스트 (N개)
| # | 테스트 클래스 | 검증 대상 | 테스트 케이스 수 |
|---|-------------|----------|---------------|

#### E2E 테스트 (N개)
| # | 테스트 클래스 | 검증 대상 | 테스트 케이스 수 |
|---|-------------|----------|---------------|
```

AskUserQuestion으로 승인/수정을 받은 후 Step 3으로 진행한다.

## Step 3: 테스트 작성

승인된 계획에 따라 테스트를 작성한다. `TEST_CONVENTIONS`에서 파악한 기존 스타일을 준수한다.

### 작성 순서

1. **단위 테스트** → 2. **통합 테스트** → 3. **E2E 테스트**

각 유형별로:
1. `Task(subagent_type="coder")`에 다음을 전달:
   - 대상 소스 코드
   - 기존 테스트 스타일 (TEST_CONVENTIONS)
   - 테스트 계획의 해당 유형 항목
   - 프로젝트 루트 경로
2. coder가 테스트 파일을 생성/수정한다.
3. 작성 완료 후 다음 유형으로 진행한다.

### 작성 규칙

- **기존 테스트 스타일을 따른다**: Step 0-3에서 분석한 네이밍, import, assertion, 데이터 생성 패턴을 그대로 사용한다.
- **디렉토리 구조를 따른다**: 기존 테스트 디렉토리 구조와 동일한 위치에 파일을 생성한다.
- **테스트 독립성**: 각 테스트는 다른 테스트에 의존하지 않는다.
- **테스트 명명**: 한국어 또는 프로젝트 기존 패턴을 따른다. 메서드명에 검증 대상과 기대 결과를 명시한다.
- **Given-When-Then** 또는 프로젝트 기존 패턴을 사용한다.

### TEST_TYPE별 분기

- `--type unit`: 단위 테스트만 작성
- `--type integration`: 통합 테스트만 작성
- `--type e2e`: E2E 테스트만 작성
- `--type all` (기본값): 전체 작성

## Step 4: 테스트 실행 및 검증

### 4-1: 테스트 실행

프로젝트 타입별 테스트 명령을 실행한다 (`timeout: 300000`):

| 프로젝트 타입 | 테스트 명령 |
|--------------|-----------|
| java-spring | `./gradlew test` |
| node | `npm test` 또는 `bun test` |
| python | `pytest` |

### 4-2: 실패 처리

테스트 실패 시:
1. 실패 로그를 분석하여 원인을 파악한다.
2. `Task(subagent_type="coder")`에 실패 로그와 테스트 코드를 전달하여 수정 요청.
3. 수정 후 테스트를 **1회 재실행**한다.
4. 재실행도 실패하면 사용자에게 실패 목록을 보고하고 진행 여부를 확인한다.

### 4-3: 커버리지 확인

테스트 통과 후 커버리지를 확인한다:

**java-spring**:
- `./gradlew jacocoTestReport` 실행 (JaCoCo 플러그인이 있으면)
- 보고서에서 도메인 패키지의 커버리지를 추출

**node**:
- `npm test -- --coverage` 또는 `bun test --coverage`
- 커버리지 요약에서 대상 디렉토리의 수치를 추출

**python**:
- `pytest --cov={도메인 패키지}`
- 커버리지 요약을 추출

커버리지 도구가 없거나 실행 불가 시 이 단계를 건너뛴다.

## Step 5: 결과 보고

```
## 테스트 결과: {도메인}

### 작성 완료
- 단위 테스트: N개 파일 / M개 케이스
- 통합 테스트: N개 파일 / M개 케이스
- E2E 테스트: N개 파일 / M개 케이스

### 테스트 실행
- 전체: N개 통과 / M개 실패
- 커버리지: N% (목표: {COVERAGE_TARGET}%)

### 작성된 파일
| 유형 | 파일 경로 |
|------|----------|
| 단위 | src/test/domain/{도메인}/{Class}Test.kt |
| 통합 | src/test/domain/{도메인}/{Service}IntegrationTest.kt |
| E2E | src/test/interfaces/api/{도메인}/{Controller}E2ETest.kt |
```

커버리지가 `COVERAGE_TARGET` 미만이면:
- 추가 테스트 작성 여부를 AskUserQuestion으로 확인한다.
- "예" → Step 2로 돌아가 누락 분석부터 재실행.
- "아니오" → 현재 상태로 완료.
