---
layout: default
title: Codex 사용 가이드
permalink: /codex/
---

# Codex에서 Ttuk Ttak 사용하기

플러그인 관리 명령을 지원하는 Codex CLI, Git, Python 3.10 이상과 프로젝트별 테스트·빌드 도구를 준비합니다. Windows는 Git Bash가 필요하며 `codex`를 `codex.cmd`로 바꿉니다. 이식 버전의 현재 확인 범위는 [이식 보고서](migration-2.0.0.md)를 참고하세요.

## 설치

기존 ttutak 설치가 있으면 [이전 안내](migration-2.0.0.md#기존-설치-이전)를 먼저 따릅니다. 아래 원격 명령은 2.0.0 변경이 기존 저장소에 반영된 이후에 사용합니다.

```bash
codex plugin marketplace add rnqhstmd/ttutak
codex plugin add ttuk-ttak@ttuk-ttak
codex plugin list --json
```

프로젝트 폴더에서 새 세션을 열고 `/skills`로 `ttuk-ttak` 스킬, `/hooks`로 훅 정의와 신뢰 상태를 확인합니다. 훅이 표시되지 않거나 신뢰되지 않으면 보호 훅이 실행된다고 볼 수 없습니다.

## 채팅으로 사용

다음 요청은 터미널 명령이 아닙니다. Codex 입력창에 단계별로 입력합니다.

```text
ttuk-ttak:setup 스킬로 이 프로젝트를 준비해줘.
ttuk-ttak:tdd --core로 로그인 입력 검증을 테스트 먼저 구현해줘.
ttuk-ttak:cross-review --advisor native로 변경사항을 검토해줘.
ttuk-ttak:verify로 테스트와 빌드를 실행해 검증해줘.
```

`setup`은 기존 `.claude/config.json` 설정을 보존하며 프로젝트 테스트·빌드 명령을 준비합니다. 일반 개발은 `ttuk-ttak:dev`로 요청합니다. native 리뷰는 현재 Codex의 역할 에이전트를 사용합니다. 외부 Codex를 다시 실행하는 리뷰에는 별도 홈 경로·샌드박스 제약이 있을 수 있습니다.

```text
ttuk-ttak:commit으로 이번 변경을 커밋해줘.
ttuk-ttak:pull-request로 main 대상 PR을 만들어줘.
```

커밋은 작업 브랜치에서 진행하며 미검증·검증 후 코드 변경 상태에서는 보호 훅이 차단합니다. 실제 권한은 Codex의 승인 정책을 따릅니다. 무인 Ralph 실행은 필요한 권한이 없으면 BLOCKED로 종료하며 권한을 우회하지 않습니다. PR 머지는 사용자가 진행합니다.

## 갱신과 확인

```bash
codex plugin marketplace list --json
codex plugin marketplace upgrade ttuk-ttak
codex plugin add ttuk-ttak@ttuk-ttak
codex plugin list --json
```

현재 Codex 버전에서 명령이 다르면 `codex plugin --help`와 `codex plugin marketplace --help`를 확인합니다. 갱신은 등록한 ref를 따르므로 설치 버전과 소스를 함께 확인합니다. 새 세션에서 스킬·훅을 다시 확인합니다.

Superpowers와 함께 설치했다면 `ttuk-ttak:tdd`, `Superpowers writing-plans`처럼 사용할 플러그인과 스킬을 명시합니다.

역할의 도구 목록은 지침이며 권한을 강제하는 경계가 아닙니다. upstream Windows 측정 결과는 [보관 자료](upstream-history.md)에 있으며 Ttuk Ttak 2.0.0의 실행 검증을 대신하지 않습니다.
