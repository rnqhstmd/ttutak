<div align="center">

# Ttuk Ttak · 뚝딱

**아이디어를 코드로, 뚝딱.**

Claude Code와 Codex에서 PRD → 설계 → 구현 → 리뷰 → 검증 → PR까지 에이전트 팀이 처리하는 개발 자동화 플러그인.

[사용 가이드](https://rnqhstmd.github.io/ttutak/) · [Codex 가이드](docs/codex-guide.md) · [2.0.0 이식 안내](docs/migration-2.0.0.md)

</div>

## 설치와 시작

표시 이름은 **Ttuk Ttak**, 플러그인·마켓플레이스 식별자는 **`ttuk-ttak`**입니다. 저장소 주소는 기존 `rnqhstmd/ttutak`을 유지합니다. 아래 원격 설치는 2.0.0 변경이 해당 저장소에 반영된 뒤 사용할 수 있습니다.

### Claude Code

Claude Code 입력창에서 실행합니다.

```text
/plugin marketplace add rnqhstmd/ttutak
/plugin install ttuk-ttak@ttuk-ttak
/ttuk-ttak:setup
```

기존 ttutak 사용자는 먼저 [설치 이전 절차](docs/migration-2.0.0.md#기존-설치-이전)를 진행합니다. 이름 변경으로 구형과 신형이 함께 활성화되면 훅과 스킬이 중복 실행될 수 있습니다.

### Codex

플러그인 관리 명령을 지원하는 Codex CLI에서 실행합니다. Windows는 `codex` 대신 `codex.cmd`를 사용합니다.

```bash
codex plugin marketplace add rnqhstmd/ttutak
codex plugin add ttuk-ttak@ttuk-ttak
codex plugin list --json
```

새 프로젝트 세션에서 `/skills`와 `/hooks`로 설치·훅 신뢰 상태를 확인합니다. 아래 문장은 **Codex 채팅창에** 입력합니다.

```text
ttuk-ttak:setup 스킬로 이 프로젝트를 준비해줘.
ttuk-ttak:tdd --core로 이 기능을 테스트 먼저 구현해줘.
ttuk-ttak:cross-review --advisor native로 변경사항을 검토해줘.
ttuk-ttak:verify로 테스트와 빌드를 실행해 검증해줘.
```

환경별 설치·갱신과 권한 제약은 [Codex 가이드](docs/codex-guide.md)를 참고하세요.

## 사용법

명령을 명시하거나 자연어로 요청합니다. `context`로 도메인을 등록하고, 일반 개발은 `dev`, 테스트부터 시작하는 개발은 `tdd`로 진행합니다. `--core`는 작은 변경, 전체 모드는 PRD부터 PR까지의 흐름에 사용합니다. `--ralph`는 사용자가 명시적으로 선택한 무인 반복 경로입니다.

| 요청 | 스킬 |
|---|---|
| "기획서 보고 context 만들어줘" | context |
| "결제 정책 확인해줘" | lens |
| "대시보드 기능 개발해줘" | dev |
| "TDD로 로그인 검증 구현해줘" | tdd |
| "실패 테스트 먼저 작성해줘" | red |
| "테스트 통과시켜줘" | green |
| "중복 제거 정리해줘" | refactor |
| "완료 검증해줘" | verify |
| "랄프 루프 준비해줘" | ralph |
| "교차 리뷰 해줘" | cross-review |
| "테스트 작성해줘" | test (기존 Spring 프로젝트용) |
| "기술 부채 분석해줘" | tech-debt |
| "커밋해줘 / PR 만들어줘" | commit / pull-request |
| "AI 흔적 교정해줘 / 조사해줘" | humanizer / research |

18개 스킬(`setup`, 내부 반복용 `ralph-iterate` 포함), 17개 역할 에이전트를 제공합니다. `test`는 기존 Spring 전용 테스트 작업과의 호환을 위해 유지하며, 언어 중립 개발에는 `tdd`를 사용합니다.

작업 계획 `.dev/plan.md`에 ID가 있다면 `/ttuk-ttak:dev --work W01` 또는 `/ttuk-ttak:tdd --work W01`로 해당 범위를 실행합니다.

## 프로젝트 설정과 안전장치

`setup`은 VCS·테스트·빌드 명령을 확인합니다. 프로젝트 `.claude/config.json`에서 프로젝트 타입, 모델 프로파일, Google Chat·Slack 알림 설정을 관리합니다. 기존 사용자 값과 웹훅을 백업하고 보존한 상태에서 갱신합니다. `context/`는 도메인 지식, `references/`는 준수해야 할 규격, `.dev/`는 작업 상태·설계·의사결정 기록을 담습니다.

TDD는 RED → GREEN → REFACTOR 순서를 따릅니다. `verify`는 실제 테스트·빌드 실행과 코드 지문을 기록하고, 보호 훅은 미검증·변경 후 오래된 검증 상태에서 커밋을 차단합니다. 보호 브랜치·강제 푸시·민감 파일을 점검하고 PR 머지는 사용자가 진행합니다. 알림 설정은 선택 사항입니다.

## 하네스 지원과 검증 범위

Claude Code용 스킬·에이전트와 Codex용 역할 번들·설정 템플릿·훅 어댑터를 함께 배포합니다. Codex 역할 도구 목록은 프롬프트 지침이며 실제 권한 경계를 대신하지 않습니다. 설치된 훅의 신뢰 상태와 프로젝트 테스트 명령을 확인해야 합니다.

이 버전은 **oh-my-gx v1.33.0 (`e807c65`)**을 기반으로 ttutak의 Slack 알림·민감 파일 오탐 방지·릴리스 검사와 기존 `test` 스킬을 통합했습니다. [이식 보고서](docs/migration-2.0.0.md)와 [스킬·문서 재검증 결과](docs/reaudit-2026-10-11.md)에 확인 범위를 기록합니다. 원본 17개 스킬의 실행 규약은 대조했으며, 18개 전체의 양쪽 인증 모델 실행 동일성은 아직 검증하지 않았습니다. 과거 Windows 실행 증거는 [upstream 자료](docs/upstream-history.md)이며 이 버전의 실행 결과와 구분합니다.

상세 참고: [전체 가이드](docs/guide.md), [TDD 가이드](docs/tdd-guide.md), [프롬프트 예시](docs/prompt-examples.md), [테스트 하네스](docs/test-harness-guide.md), [변경 이력](CHANGELOG.md).
