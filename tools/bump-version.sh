#!/usr/bin/env bash
# Claude / marketplace / Codex 매니페스트 버전을 함께 갱신한다.
# 사용: tools/bump-version.sh MAJOR.MINOR.PATCH
set -euo pipefail
V="${1:-}"
if ! [[ "$V" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
  echo "error: invalid version format: $V (expected: MAJOR.MINOR.PATCH)" >&2
  exit 1
fi
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN="$ROOT/.claude-plugin/plugin.json"
MARKET="$ROOT/.claude-plugin/marketplace.json"
CODEX="$ROOT/.codex-plugin/plugin.json"
FILES=("$PLUGIN" "$MARKET" "$CODEX")
command -v jq >/dev/null 2>&1 || { echo 'error: jq가 필요합니다.' >&2; exit 1; }
for f in "${FILES[@]}"; do
  [ -f "$f" ] || { echo "error: $f 를 찾을 수 없습니다." >&2; exit 1; }
  # 다른 실행의 백업을 덮어쓰거나 삭제하지 않는다.
  [ ! -e "$f.bak" ] && [ ! -e "$f.tmp" ] || { echo "error: $f 갱신 임시 파일이 이미 존재합니다." >&2; exit 1; }
done
COMMIT_STARTED=false
COMMIT_SUCCEEDED=false
cleanup_on_exit() {
  local code=$? rollback_failed=false f
  trap - EXIT
  if [ "$COMMIT_STARTED" = true ] && [ "$COMMIT_SUCCEEDED" != true ]; then
    for f in "${FILES[@]}"; do
      if ! cp -p "$f.bak" "$f"; then rollback_failed=true; fi
    done
    if [ "$rollback_failed" = true ]; then
      echo 'error: 롤백 실패 — .bak 파일을 보존했습니다.' >&2
      rm -f "${FILES[@]/%/.tmp}"
      exit 1
    fi
    echo 'error: 원자적 갱신 실패 — 원본으로 롤백했습니다.' >&2
  fi
  rm -f "${FILES[@]/%/.tmp}" "${FILES[@]/%/.bak}"
  exit "$code"
}
trap cleanup_on_exit EXIT
PLUGIN_NAME=$(jq -er '.name | select(type == "string" and length > 0)' "$PLUGIN")
jq -e --arg name "$PLUGIN_NAME" '.name == $name' "$CODEX" >/dev/null || { echo 'error: Claude / Codex plugin name mismatch' >&2; exit 1; }
jq -e --arg name "$PLUGIN_NAME" '[.plugins[]? | select(.name == $name)] | length == 1' "$MARKET" >/dev/null || { echo 'error: marketplace must contain exactly one matching plugin' >&2; exit 1; }
jq --arg v "$V" '.version = $v' "$PLUGIN" > "$PLUGIN.tmp"
jq --arg v "$V" --arg name "$PLUGIN_NAME" '(.plugins[] | select(.name == $name)).version = $v' "$MARKET" > "$MARKET.tmp"
jq --arg v "$V" '.version = $v' "$CODEX" > "$CODEX.tmp"
for f in "$PLUGIN" "$CODEX"; do
  jq -e --arg v "$V" --arg name "$PLUGIN_NAME" '.version == $v and .name == $name' "$f.tmp" >/dev/null
done
jq -e --arg v "$V" --arg name "$PLUGIN_NAME" '[.plugins[] | select(.name == $name and .version == $v)] | length == 1' "$MARKET.tmp" >/dev/null
for f in "${FILES[@]}"; do cp -p "$f" "$f.bak"; done
COMMIT_STARTED=true
for f in "${FILES[@]}"; do mv "$f.tmp" "$f"; done
COMMIT_SUCCEEDED=true
echo "✅ Claude / marketplace / Codex → $V"
VERSION_RE=${V//./\\.}
if [ -f "$ROOT/CHANGELOG.md" ] && grep -Eq "^## v${VERSION_RE}([ (]|$)" "$ROOT/CHANGELOG.md"; then
  echo "✅ CHANGELOG.md: ## v$V 섹션 확인"
else
  echo "WARNING: CHANGELOG.md에 ## v$V 섹션이 없습니다." >&2
fi
