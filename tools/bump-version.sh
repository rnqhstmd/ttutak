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

# 원자적 갱신: 두 파일 모두 tmp로 먼저 생성하고, 전부 검증된 뒤에만 원본 교체
cleanup_tmp() {
  rm -f "$PLUGIN.tmp" "$MARKET.tmp"
}
trap cleanup_tmp EXIT

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

# 두 tmp 생성 (실패 시 trap이 정리)
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

# 모든 검증 통과 후에만 원본 교체 (부분 적용 방지)
mv "$PLUGIN.tmp" "$PLUGIN"
mv "$MARKET.tmp" "$MARKET"
trap - EXIT

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
