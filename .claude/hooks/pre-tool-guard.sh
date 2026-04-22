#!/usr/bin/env bash
# 워크스페이스 PreToolUse Guard — Bash 명령 차단 규칙
# JSON permissionDecision 출력으로 차단, exit 0으로 통과
#
# 가드 정책:
#   G1. 보호 브랜치(main/master/develop)에서 `git commit` 차단
#   G2. detached HEAD 상태에서 `git commit` 차단
#
# 입력: stdin으로 PreToolUse 이벤트 JSON
# 추출 우선순위: jq로 tool_input.command → 실패 시 fallback(전체 JSON 문자열)

set -uo pipefail

INPUT=$(cat /dev/stdin 2>/dev/null || echo '{}')

# 1) tool_input.command 추출
CMD=""
if command -v jq >/dev/null 2>&1; then
  CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")
fi
# jq 없거나 추출 실패 시 전체 JSON을 대상으로 삼되, 단어 경계 regex는 그대로 적용
if [ -z "$CMD" ]; then
  CMD="$INPUT"
fi

# 2) `git commit` 단어 경계 매칭
#    - `git` 앞: 선두, 공백, `;&|(`, 또는 JSON 값 `"` 직후
#    - `git`과 `commit` 사이: 임의 토큰 허용 (--no-pager, -C <path>, --git-dir=... 등)
#    - `commit` 뒤: 공백 또는 문자열 끝 (commitstats 같은 substring false positive 제거)
if ! printf '%s' "$CMD" | grep -Eq '(^|[[:space:];&|("])git([[:space:]]+[^[:space:]]+)*[[:space:]]+commit([[:space:]]|$)'; then
  exit 0
fi

# 3) -C <path> 경로 추출 (quoted/unquoted 모두 지원). 없으면 CWD 사용.
GIT_PATH="."
GIT_C_EXTRACT=$(printf '%s' "$CMD" | sed -E -n 's/.*git[[:space:]]+-C[[:space:]]+("([^"]+)"|'"'"'([^'"'"']+)'"'"'|([^[:space:]]+)).*/\2\3\4/p' | head -n1)
if [ -n "$GIT_C_EXTRACT" ]; then
  GIT_PATH="$GIT_C_EXTRACT"
fi

# 4) 현재 브랜치 식별 (symbolic-ref 우선)
CURRENT_BRANCH=$(git -C "$GIT_PATH" symbolic-ref --short HEAD 2>/dev/null || echo "")

# 5) 가드 판정
DENY_REASON=""

if [ -z "$CURRENT_BRANCH" ]; then
  # symbolic-ref 실패 → HEAD가 유효한 커밋을 가리키면 detached 상태로 간주
  if git -C "$GIT_PATH" rev-parse --verify HEAD >/dev/null 2>&1; then
    DENY_REASON="detached HEAD 상태에서는 커밋할 수 없습니다. 작업 브랜치를 먼저 생성하거나 checkout 하세요."
  fi
  # 저장소가 아닌 경우는 통과 (git 자체가 실패하도록 둠)
elif [[ "$CURRENT_BRANCH" =~ ^(develop|main|master)$ ]]; then
  DENY_REASON="${CURRENT_BRANCH} 브랜치에서는 커밋할 수 없습니다. 작업 브랜치를 먼저 생성하세요."
fi

if [ -n "$DENY_REASON" ]; then
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "${DENY_REASON}"
  }
}
EOF
  exit 0
fi

exit 0
