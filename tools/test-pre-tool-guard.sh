#!/usr/bin/env bash
# pre-tool-guard.sh 단위 테스트
# 사용: bash tools/test-pre-tool-guard.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$SCRIPT_DIR/.claude/hooks/pre-tool-guard.sh"

require_command() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "FAIL: 필수 명령을 찾을 수 없습니다: $cmd"
    exit 1
  fi
}

if [ ! -f "$HOOK" ]; then
  echo "FAIL: 훅 스크립트를 찾을 수 없습니다: $HOOK"
  exit 1
fi

require_command bash
require_command git
require_command grep
require_command mktemp
require_command jq

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# 테스트용 git 저장소 준비: (1) main, (2) feat/test, (3) detached HEAD
init_repo() {
  local dir="$1"
  local branch="$2"
  mkdir -p "$dir"
  (
    cd "$dir"
    git init -q -b main
    git config user.email "test@test.local"
    git config user.name "test"
    echo "seed" > README
    git add README
    git commit -q -m "seed"
    if [ "$branch" != "main" ] && [ "$branch" != "detached" ]; then
      git checkout -q -b "$branch"
    elif [ "$branch" = "detached" ]; then
      local sha
      sha=$(git rev-parse HEAD)
      git checkout -q "$sha"
    fi
  )
}

REPO_MAIN="$TMPDIR/repo-main"
REPO_FEAT="$TMPDIR/repo-feat"
REPO_DETACHED="$TMPDIR/repo-detached"
init_repo "$REPO_MAIN" "main"
init_repo "$REPO_FEAT" "feat/test"
init_repo "$REPO_DETACHED" "detached"

PASS=0
FAIL=0
FAILED_CASES=()

# run_case <이름> <기대(allow|deny)> <CWD> <command>
#   JSON 입력 생성은 jq -Rn으로 안전하게 escape한다 (python3 의존 제거).
run_case() {
  local name="$1"
  local expected="$2"
  local cwd="$3"
  local cmd="$4"

  local input
  input=$(jq -Rn --arg c "$cmd" '{tool_input: {command: $c}}')

  local output
  output=$(cd "$cwd" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null || true)

  local actual="allow"
  if printf '%s' "$output" | grep -q '"permissionDecision"[[:space:]]*:[[:space:]]*"deny"'; then
    actual="deny"
  fi

  if [ "$actual" = "$expected" ]; then
    PASS=$((PASS + 1))
    printf "  ✅ %s\n" "$name"
  else
    FAIL=$((FAIL + 1))
    FAILED_CASES+=("$name (expected=$expected actual=$actual)")
    printf "  ❌ %s — expected=%s actual=%s\n" "$name" "$expected" "$actual"
    printf "     output: %s\n" "$output"
  fi
}

echo "=== pre-tool-guard.sh 단위 테스트 ==="

# 기본 커버리지
run_case "a. main 브랜치 git commit 차단" \
  "deny" "$REPO_MAIN" "git commit -m msg"

run_case "b. 작업 브랜치 git commit 허용" \
  "allow" "$REPO_FEAT" "git commit -m msg"

run_case "c. detached HEAD git commit 차단" \
  "deny" "$REPO_DETACHED" "git commit -m msg"

run_case "d. git commitstats (false positive 방지)" \
  "allow" "$REPO_MAIN" "echo git commitstats"

run_case "e. git -C <main repo> commit 차단" \
  "deny" "$REPO_FEAT" "git -C $REPO_MAIN commit -m msg"

run_case "f. 비-git 명령 허용" \
  "allow" "$REPO_MAIN" "ls -la"

run_case "g. git -C <feat repo> commit 허용" \
  "allow" "$REPO_MAIN" "git -C $REPO_FEAT commit -m msg"

run_case "h. git push 허용" \
  "allow" "$REPO_MAIN" "git push origin main"

# 중간 옵션 대응
run_case "i. git --no-pager commit 차단 (중간 옵션)" \
  "deny" "$REPO_MAIN" "git --no-pager commit -m msg"

run_case "j. git --git-dir=... commit 허용" \
  "allow" "$REPO_FEAT" "git --git-dir=/tmp/x.git --work-tree=/tmp commit -m msg"

# 접미사 `"` 대응 (fallback 모드 시뮬레이션)
run_case "k. 세그먼트 말미가 \" (fallback 경계) 차단" \
  "deny" "$REPO_MAIN" 'git commit'

# 복합 명령: 각 세그먼트를 독립적으로 가드해야 함
run_case "l. 복합명령 - 첫 세그먼트 main 차단" \
  "deny" "$REPO_FEAT" "git -C $REPO_MAIN commit -m a; git -C $REPO_FEAT commit -m b"

run_case "m. 복합명령 - 두번째 세그먼트 main 차단" \
  "deny" "$REPO_FEAT" "git -C $REPO_FEAT commit -m a && git -C $REPO_MAIN commit -m b"

run_case "n. 복합명령 - 양쪽 모두 feat 허용" \
  "allow" "$REPO_MAIN" "git -C $REPO_FEAT commit -m a && git -C $REPO_FEAT commit -m b"

# `-C` 추출 보강: 공백 없는 -C/path, 다중 -C 마지막 적용
run_case "o. -C/path 공백 없는 형식 차단 (main)" \
  "deny" "$REPO_FEAT" "git -C$REPO_MAIN commit -m msg"

run_case "p. 다중 -C 마지막이 main이면 차단" \
  "deny" "$REPO_FEAT" "git -C $REPO_FEAT -C $REPO_MAIN commit -m msg"

run_case "q. 다중 -C 마지막이 feat이면 허용" \
  "allow" "$REPO_MAIN" "git -C $REPO_MAIN -C $REPO_FEAT commit -m msg"

echo
echo "=== 결과: PASS=$PASS, FAIL=$FAIL ==="
if [ "$FAIL" -gt 0 ]; then
  echo "실패 케이스:"
  for c in "${FAILED_CASES[@]}"; do
    echo "  - $c"
  done
  exit 1
fi
exit 0
