# Ttuk Ttak 2.0.0 이식 보고서

작성일: 2026-10-11 (Asia/Seoul)

## 출처와 변경 범위

- 기준 upstream: [bs-koo/oh-my-gx v1.33.0](https://github.com/bs-koo/oh-my-gx/releases/tag/v1.33.0), 커밋 `e807c65`.
- 이전 ttutak 소스: v1.4.0. 기존 `CHANGELOG.md`의 이력은 그대로 유지.
- 표시 이름: **Ttuk Ttak · 뚝딱**. 식별자: `ttuk-ttak`.
- 저장소: [rnqhstmd/ttutak](https://github.com/rnqhstmd/ttutak). 저장소를 이름 변경하거나 새로운 주소를 만들지 않음.
- 17개 upstream 스킬에 기존 Spring `test`를 추가하여 18개 스킬, 17개 역할 에이전트 제공.
- TDD·verify·Ralph·Codex 역할/설정/훅 어댑터 통합. Slack 알림, 민감 파일 오탐 방지, 릴리스 버전 일치 검사 보존.
- `scripts/gx-ralph.sh` 같은 내부 러너 파일명은 호환을 위해 유지. 사용자 명령은 `/ttuk-ttak:ralph`.

## 기존 설치 이전

사용자 프로젝트의 `.claude/config.json`, 알림 설정·웹훅, `context/`, `.dev/`를 백업합니다. 플러그인 캐시 안에 직접 추가한 자료가 있다면 캐시 밖에 보관합니다. 사용자 프로젝트 파일을 플러그인 기본값으로 통째로 덮지 않습니다.

Claude Code 입력창에서 이전 플러그인과 마켓플레이스를 제거한 뒤 새 이름으로 설치합니다. 이전 마켓플레이스에 다른 플러그인도 등록돼 있다면 목록을 확인하고 해당 항목에 미치는 영향을 먼저 확인합니다.

```text
/plugin uninstall ttutak@ttutak
/plugin marketplace remove ttutak
/plugin marketplace add rnqhstmd/ttutak
/plugin install ttuk-ttak@ttuk-ttak
```

설치 변경이 원격 저장소에 반영되기 전에는 원격 설치로 2.0.0을 받을 수 없습니다. 현재 체크아웃을 검토하려면 로컬 마켓플레이스를 사용합니다. 새 세션에서 `/ttuk-ttak:setup`을 실행하고 사용자 설정 보존·Slack/Google Chat 값과 훅을 확인합니다. 구형 `ttutak`이 함께 활성화되지 않았는지 설치 목록을 확인합니다. 사용자 문서의 `/ttutak:...` 명령도 `/ttuk-ttak:...`으로 갱신합니다.

Codex CLI 0.159.2에서는 다음 제거 명령을 지원합니다. 기존 설치 이름을 목록에서 확인한 뒤 실행합니다.

```bash
codex plugin remove ttutak@ttutak
codex plugin marketplace remove ttutak
```

Codex는 설치 목록에서 기존 플러그인을 먼저 확인합니다. `codex plugin --help`가 제공하는 제거 명령 또는 앱 플러그인 관리 화면으로 구형을 비활성화/제거하고, 마켓플레이스의 기존 등록도 정리합니다. 버전마다 지원되는 CLI 명령이 다르므로 확인되지 않은 제거 문법을 그대로 실행하지 않습니다. 이후 [Codex 가이드](codex-guide.md)에 따라 새 이름을 설치하고 새 세션의 `/skills`·`/hooks`를 확인합니다.

## 검증 기록

후속 [스킬·문서 재검증](reaudit-2026-10-11.md)에서 인용 메시지의 `-C` 보호 훅 회귀, Windows 인용 경로와 문서 오류를 수정했다. 수정 후 Python 166개 중 161개 통과·Windows 전용 5개 skip, native 로더 인벤토리 및 제한된 Codex 실제 모델 2개 사례를 별도로 기록한다. 아래는 최초 이식 시점 결과다.

macOS에서 소스 이식과 하네스용 배포 파일을 검증했습니다. 원격 릴리스 설치와 소비 프로젝트의 setup → TDD → 리뷰 → verify 전체 인증 모델 실행은 이번 결과에 포함되지 않습니다.

- Python 회귀: `python3 -m unittest discover -s tests -p 'test_*.py' -v` — 164개 실행, 실패 0개, Windows 전용 5개 건너뜀(159개 통과). 이식·릴리스 호환성 12개 포함.
- 정합성 린트 36항목, 기존 ttutak 보호 훅 17개, 최신 훅 6그룹, Ralph mock 36개, 행동 테스트 mock 30개 통과.
- Codex 생성물 `--check`와 `git diff --check` 통과. 독립 리뷰에서 발견한 `git -C`/복합 명령/detached HEAD 보호 회귀와 Spring `projectTypes[type].test` 설정 경로 오류를 수정하고 재검증.
- CI는 Linux에서 기존 보호 훅·이식 호환성을, Linux/Windows에서 Codex 계약을 검사하도록 구성. [GitHub Actions 실행 38123694252](https://github.com/rnqhstmd/ttutak/actions/runs/38123694252)의 커밋 `e39ada5`에서 consistency·Ubuntu Codex 계약·Windows Codex 계약 3개 job 모두 통과. Windows의 실제 인증 모델 실행과는 별개인 오프라인 계약 검증 결과임.
- 브라우저에서 홈페이지 표시 이름·스킬 수·설치 안내와 최신 TDD 설명 확인.

- Claude Code CLI 2.1.227에서 `plugin uninstall`, `plugin marketplace remove` 지원을 도움말로 확인.
- Claude Code native 인벤토리(`claude --plugin-dir … plugin details ttuk-ttak`)에서 버전 2.0.0, 스킬 18개, 에이전트 17개, 훅 2개 발견. 플러그인 manifest 검증 통과. 루트 `CLAUDE.md`는 설치 소비 프로젝트에 자동 로드되지 않는다는 정상 경고 확인.
- PATH의 Codex npm 실행 파일은 native 실행 파일 부재(`ENOENT`)로 실행 실패. 별도 bundled Codex CLI 0.159.2의 플러그인·마켓플레이스 명령을 확인하고, app-server `plugin/read`로 새 marketplace의 `ttuk-ttak@ttuk-ttak` Git source가 인식됨을 확인. 이것은 설치·스킬 로드·훅 신뢰 검증을 의미하지 않음.
- 현재 Claude Code는 미로그인 상태. 플러그인 인벤토리 검증은 인증 모델 실행 없이 수행했으며, 실제 소비 프로젝트 전체 실행은 로그인 후 확인해야 함.
- upstream의 Windows Codex 과거 실측은 [별도 보관 자료](upstream-history.md)이며 새 버전 실행 증거가 아님.

## 다음 upstream 갱신

새 upstream 태그를 별도 체크아웃에서 비교한 뒤 현재 이식의 추가 변경(Slack, 민감 파일 검사, 릴리스 검사, `test`, 브랜드)을 재적용합니다. upstream 버전·SHA와 재적용 목록을 이와 같은 보고서에 남기고, 스킬·설정·훅 번들의 참조 검사와 회귀 검사를 수행합니다.
