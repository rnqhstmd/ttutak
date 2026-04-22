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

# plugin.json 갱신
jq --arg v "$V" '.version = $v' "$PLUGIN" > "$PLUGIN.tmp"
mv "$PLUGIN.tmp" "$PLUGIN"

# marketplace.json 갱신 (plugins[0].version)
jq --arg v "$V" '.plugins[0].version = $v' "$MARKET" > "$MARKET.tmp"
mv "$MARKET.tmp" "$MARKET"

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
