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
#
# 복합 명령 대응: `;` `&&` `||` `|` 로 분할한 세그먼트 각각에 대해
# `-C <path>` 경로와 `git commit` 매칭을 같은 세그먼트 내에서만 해석한다.
# 이렇게 해야 `git -C protected_repo commit && git commit` 같은 우회를 막을 수 있다.

set -uo pipefail

INPUT=$(cat /dev/stdin 2>/dev/null || echo '{}')

# 1) tool_input.command 추출
CMD=""
if command -v jq >/dev/null 2>&1; then
  CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")
fi
if [ -z "$CMD" ]; then
  CMD="$INPUT"
fi

# 2) 복합 명령을 연산자/파이프 기준으로 세그먼트화
NORMALIZED=$(printf '%s' "$CMD" | tr ';|&' '\n')

DENY_REASON=""

# check_segment: 세그먼트에 `git ... commit` 매치가 있으면 가드 판정.
#   - 매치: (^|[[:space:];&|("]) git <mid-tokens> commit ([[:space:]]|"|$)
#   - -C <path>는 같은 세그먼트 내에서만 추출 (quoted / single-quoted / unquoted)
#   - 접미사 `"` 포함: JSON 값 끝에 위치한 `"command":"git commit"` 대응
# 반환: 차단 필요 시 0 (DENY_REASON 설정), 아니면 1
check_segment() {
  local seg="$1"
  if [[ ! "$seg" =~ (^|[[:space:]\;\&\|\(\"])git([[:space:]]+[^[:space:]]+)*[[:space:]]+commit([[:space:]]|\"|$) ]]; then
    return 1
  fi

  local git_path="."
  if [[ "$seg" =~ -C[[:space:]]+(\"([^\"]+)\"|\'([^\']+)\'|([^[:space:]]+)) ]]; then
    git_path="${BASH_REMATCH[2]}${BASH_REMATCH[3]}${BASH_REMATCH[4]}"
  fi

  local branch
  branch=$(git -C "$git_path" symbolic-ref --short HEAD 2>/dev/null || echo "")
  if [ -z "$branch" ]; then
    if git -C "$git_path" rev-parse --verify HEAD >/dev/null 2>&1; then
      DENY_REASON="detached HEAD 상태에서는 커밋할 수 없습니다. 작업 브랜치를 먼저 생성하거나 checkout 하세요."
      return 0
    fi
    return 1
  fi

  if [[ "$branch" =~ ^(develop|main|master)$ ]]; then
    DENY_REASON="${branch} 브랜치에서는 커밋할 수 없습니다. 작업 브랜치를 먼저 생성하세요."
    return 0
  fi

  return 1
}

while IFS= read -r seg; do
  if check_segment "$seg"; then
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
done <<< "$NORMALIZED"

exit 0
