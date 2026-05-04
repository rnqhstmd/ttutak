#!/usr/bin/env bash
# plugin.json, marketplace.json의 버전을 일괄 갱신한다.
# CHANGELOG.md에 해당 버전 섹션이 있는지 경고한다 (자동 생성하지 않음).
#
# 사용: tools/bump-version.sh <new-version>
# 예:  tools/bump-version.sh 1.3.0

set -euo pipefail

V="${1:-}"
if [ -z "$V" ]; then
  echo "usage: tools/bump-version.sh <new-version>" >&2
  exit 1
fi

# SemVer 포맷 검증
if ! [[ "$V" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "error: invalid version format: $V (expected: MAJOR.MINOR.PATCH)" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PLUGIN="$ROOT/.claude-plugin/plugin.json"
MARKET="$ROOT/.claude-plugin/marketplace.json"
CHANGELOG="$ROOT/CHANGELOG.md"

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq가 필요합니다. brew install jq 또는 apt install jq 로 설치하세요." >&2
  exit 1
fi

for f in "$PLUGIN" "$MARKET"; do
  if [ ! -f "$f" ]; then
    echo "error: $f 를 찾을 수 없습니다." >&2
    exit 1
  fi
done

# 원자적 갱신:
#   1. 두 tmp 생성 + 검증
#   2. 두 원본을 .bak으로 백업
#   3. 두 mv 시도 (성공 시 .bak 정리, 실패 시 .bak 복원으로 부분 적용 차단)
PLUGIN_BAK="$PLUGIN.bak"
MARKET_BAK="$MARKET.bak"
COMMIT_STARTED=false
COMMIT_SUCCEEDED=false

cleanup_on_exit() {
  local code=$?
  if [ "$COMMIT_STARTED" = "true" ] && [ "$COMMIT_SUCCEEDED" != "true" ]; then
    # 두 mv 중간에 실패한 경우 백업으로 롤백
    [ -f "$PLUGIN_BAK" ] && mv -f "$PLUGIN_BAK" "$PLUGIN"
    [ -f "$MARKET_BAK" ] && mv -f "$MARKET_BAK" "$MARKET"
    echo "error: 원자적 갱신 실패 — 원본으로 롤백했습니다." >&2
  fi
  rm -f "$PLUGIN.tmp" "$MARKET.tmp" "$PLUGIN_BAK" "$MARKET_BAK"
  exit $code
}
trap cleanup_on_exit EXIT

# plugin.json의 name을 먼저 읽어 marketplace 갱신 대상 식별
PLUGIN_NAME=$(jq -r '.name' "$PLUGIN")
if [ -z "$PLUGIN_NAME" ] || [ "$PLUGIN_NAME" = "null" ]; then
  echo "error: plugin.json에 name 필드가 없습니다." >&2
  exit 1
fi

HAS_PLUGIN=$(jq --arg name "$PLUGIN_NAME" '[.plugins[]? | select(.name == $name)] | length' "$MARKET")
if [ "$HAS_PLUGIN" = "0" ]; then
  echo "error: marketplace.json의 plugins[] 에 name='$PLUGIN_NAME' 항목이 없습니다." >&2
  exit 1
fi

# 1. 두 tmp 생성 (실패 시 trap이 정리)
jq --arg v "$V" '.version = $v' "$PLUGIN" > "$PLUGIN.tmp"
jq --arg v "$V" --arg name "$PLUGIN_NAME" '(.plugins[] | select(.name == $name)).version = $v' "$MARKET" > "$MARKET.tmp"

# 검증: 두 tmp 모두 유효한 JSON이고 기대한 버전이 담겨있는지 확인
jq -e . "$PLUGIN.tmp" >/dev/null 2>&1 || { echo "error: plugin.json.tmp JSON 검증 실패" >&2; exit 1; }
jq -e . "$MARKET.tmp" >/dev/null 2>&1 || { echo "error: marketplace.json.tmp JSON 검증 실패" >&2; exit 1; }
TMP_PV=$(jq -r '.version' "$PLUGIN.tmp")
TMP_MV=$(jq -r --arg name "$PLUGIN_NAME" '.plugins[] | select(.name == $name) | .version' "$MARKET.tmp")
if [ "$TMP_PV" != "$V" ] || [ "$TMP_MV" != "$V" ]; then
  echo "error: tmp 파일의 버전이 $V 와 일치하지 않습니다 (plugin=$TMP_PV marketplace=$TMP_MV)" >&2
  exit 1
fi

# 2. 백업 — 두 mv 어느 쪽이든 실패하면 trap에서 복원
cp "$PLUGIN" "$PLUGIN_BAK"
cp "$MARKET" "$MARKET_BAK"

# 3. commit 단계: COMMIT_STARTED=true 이후 실패하면 trap이 .bak으로 롤백
COMMIT_STARTED=true
mv "$PLUGIN.tmp" "$PLUGIN"
mv "$MARKET.tmp" "$MARKET"
COMMIT_SUCCEEDED=true

echo "✅ plugin.json / marketplace.json → $V"

# CHANGELOG 검증 (경고만)
if [ -f "$CHANGELOG" ]; then
  if grep -q "^## v$V" "$CHANGELOG"; then
    echo "✅ CHANGELOG.md: ## v$V 섹션 확인"
  else
    echo "⚠️  WARNING: CHANGELOG.md에 ## v$V 섹션이 없습니다. 수동으로 추가해주세요." >&2
  fi
else
  echo "⚠️  WARNING: CHANGELOG.md 파일이 없습니다." >&2
fi
