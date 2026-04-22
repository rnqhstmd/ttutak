#!/usr/bin/env bash
# pre-tool-guard.sh 단위 테스트
# 사용: bash tools/test-pre-tool-guard.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$SCRIPT_DIR/.claude/hooks/pre-tool-guard.sh"

if [ ! -x "$HOOK" ] && [ ! -f "$HOOK" ]; then
  echo "FAIL: 훅 스크립트를 찾을 수 없습니다: $HOOK"
  exit 1
fi

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# 테스트용 git 저장소 3개 준비: (1) main 브랜치, (2) feat/test 브랜치, (3) detached HEAD
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
run_case() {
  local name="$1"
  local expected="$2"
  local cwd="$3"
  local cmd="$4"

  local input
  input=$(printf '{"tool_input":{"command":%s}}' "$(printf '%s' "$cmd" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || printf '"%s"' "$cmd")")

  local output
  output=$(cd "$cwd" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null)

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

# (a) main 브랜치에서 `git commit` → deny
run_case "a. main 브랜치 git commit 차단" \
  "deny" "$REPO_MAIN" "git commit -m msg"

# (b) 작업 브랜치(feat/test)에서 `git commit` → allow
run_case "b. 작업 브랜치 git commit 허용" \
  "allow" "$REPO_FEAT" "git commit -m msg"

# (c) detached HEAD에서 `git commit` → deny
run_case "c. detached HEAD git commit 차단" \
  "deny" "$REPO_DETACHED" "git commit -m msg"

# (d) false positive — git commit 단어가 substring으로 들어있지만 단독이 아님
run_case "d. git commitstats (false positive 방지)" \
  "allow" "$REPO_MAIN" "echo git commitstats"

# (e) `git -C <path>` 로 다른 저장소 지정 (main) → deny
run_case "e. git -C <main repo> commit 차단" \
  "deny" "$REPO_FEAT" "git -C $REPO_MAIN commit -m msg"

# (f) 비-git 명령 → allow
run_case "f. 비-git 명령 허용" \
  "allow" "$REPO_MAIN" "ls -la"

# 추가: (g) `git -C` 로 작업 브랜치 저장소 지정 (feat) → allow
run_case "g. git -C <feat repo> commit 허용" \
  "allow" "$REPO_MAIN" "git -C $REPO_FEAT commit -m msg"

# 추가: (h) git push → allow (훅은 commit만 가드)
run_case "h. git push 허용" \
  "allow" "$REPO_MAIN" "git push origin main"

# 추가: (i) main에서 `git --no-pager commit` — 중간 옵션이 있어도 가드해야 함
run_case "i. git --no-pager commit 차단 (중간 옵션)" \
  "deny" "$REPO_MAIN" "git --no-pager commit -m msg"

# 추가: (j) 작업 브랜치에서 `git --git-dir=... commit` — 중간 옵션 + 허용 경로
run_case "j. git --git-dir=... commit 허용" \
  "allow" "$REPO_FEAT" "git --git-dir=/tmp/x.git --work-tree=/tmp commit -m msg"

# 추가: (k) "git commit" — JSON 값 내 따옴표 직후 위치 (jq fallback 시뮬레이션)
#       fallback에서 INPUT 문자열이 그대로 CMD로 들어와 `"command":"git commit ..."` 형태가 됨
run_case "k. JSON 문자열 fallback (\" 접두사) 차단" \
  "deny" "$REPO_MAIN" 'command":"git commit -m msg"'

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
