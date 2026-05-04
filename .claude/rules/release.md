# 릴리스 규칙

## 릴리스 체크리스트

버전을 올릴 때 아래 파일의 `version` 필드를 반드시 함께 갱신한다:

| 파일 | 필드 |
|------|------|
| `.claude-plugin/plugin.json` | `version` |
| `.claude-plugin/marketplace.json` | `plugins[0].version` |
| `CHANGELOG.md` | 새 버전 섹션 추가 |

세 곳의 버전이 일치하지 않으면 플러그인 UI에 이전 버전이 표시된다.

## 릴리스 순서

1. `CHANGELOG.md`에 새 버전 섹션(`## v{new-version}`) 작성
2. `bash tools/bump-version.sh <new-version>` 실행 — `plugin.json`과 `marketplace.json`을 일괄 갱신하고 CHANGELOG 섹션 유무를 검증한다
3. 커밋 → PR → 머지
4. GitHub Release는 **자동 생성**됨 (`.github/workflows/release.yml`)
   - `Verify version parity` 단계가 `plugin.json` / `marketplace.json` / `CHANGELOG.md` 세 곳의 버전 일치를 검증한다. 불일치 시 릴리스를 만들지 않고 실패한다.
   - PR이 main에 머지되면 `plugin.json`에서 버전을 추출한다.
   - 해당 버전의 태그(`v{version}`)가 없으면 CHANGELOG.md에서 내용을 파싱하여 Release 생성
   - 이미 태그가 있으면 스킵 (중복 방지)

> 수동으로 plugin.json / marketplace.json 한쪽만 수정하지 말 것. 불일치하면 CI에서 실패한다.
