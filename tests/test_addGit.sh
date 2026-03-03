#!/usr/bin/env bash
# Tests for addGit()

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$TESTS_DIR")"
source "$TESTS_DIR/helpers.sh"
source "$REPO_DIR/.shell_source/functions"
unset -f rm  # prevent interactive rm() wrapper

# Git config required for commits
git config --global user.email "ci@test.local" 2>/dev/null
git config --global user.name "CI Test" 2>/dev/null
git config --global init.defaultBranch master 2>/dev/null

# Unique prefix per run to avoid collisions
PREFIX="ci_test_addgit_$$"
TMP_DIR="$(mktemp -d)"
LOCAL_GIT="$HOME/DOWNLOAD/local_GIT"

cleanup() {
    /bin/rm -rf "$TMP_DIR"
    /bin/rm -rf "${LOCAL_GIT}/${PREFIX}"*
}
trap cleanup EXIT

# Helpers
_repo_path()    { echo "${LOCAL_GIT}/$1"; }
_commit_log()   { git -C "${LOCAL_GIT}/$1" log --oneline 2>/dev/null; }
_commit_count() { _commit_log "$1" | wc -l; }

# Prepare test files
echo "server { listen 80; }" > "$TMP_DIR/nginx.conf"
mkdir -p "$TMP_DIR/conf.d"
echo "include /conf.d/*.conf;" > "$TMP_DIR/conf.d/default.conf"
touch "$TMP_DIR/empty.conf"

# ── Argument validation ───────────────────────────────────────────────────────
CI_TEST_suite "addGit — argument validation"

CI_TEST_assert_exit_ok  "--help exits 0"      addGit --help
CI_TEST_assert_exit_fail "no args → exit 1"   addGit
CI_TEST_assert_exit_fail "unknown option"      addGit --unknown-flag

# ── New repo creation ─────────────────────────────────────────────────────────
CI_TEST_suite "addGit — new repo creation"

REPO1="${PREFIX}_1"
addGit --path "$TMP_DIR" --repo "$REPO1" nginx.conf 2>/dev/null
CI_TEST_assert_eq       "create repo exits 0"          "0" "$?"
CI_TEST_assert_dir_exists "repo .git dir created"      "$(_repo_path "$REPO1")/.git"
CI_TEST_assert_file_exists "README.md created"         "$(_repo_path "$REPO1")/README.md"
CI_TEST_assert_file_exists "tracked file copied"       "$(_repo_path "$REPO1")/nginx.conf"

readme="$(cat "$(_repo_path "$REPO1")/README.md" 2>/dev/null)"
CI_TEST_assert_eq "README.md contains --path" "$TMP_DIR" "$readme"

first_commit="$(_commit_log "$REPO1" | tail -1)"
CI_TEST_assert_contains "first commit message is 'init repo'" "init repo" "$first_commit"

# ── Subdir structure ──────────────────────────────────────────────────────────
CI_TEST_suite "addGit — subdirectory structure preserved"

REPO2="${PREFIX}_2"
addGit --path "$TMP_DIR" --repo "$REPO2" conf.d/default.conf 2>/dev/null
CI_TEST_assert_file_exists "conf.d/default.conf inside repo" \
    "$(_repo_path "$REPO2")/conf.d/default.conf"

# ── Empty file skipped ────────────────────────────────────────────────────────
CI_TEST_suite "addGit — empty file handling"

REPO3="${PREFIX}_3"
out=$(addGit --path "$TMP_DIR" --repo "$REPO3" empty.conf 2>&1)
CI_TEST_assert_contains "empty file warning shown" "empty" "$out"
CI_TEST_assert_file_not_exists "empty file not copied to repo" \
    "$(_repo_path "$REPO3")/empty.conf"

# ── Reuse existing repo ───────────────────────────────────────────────────────
CI_TEST_suite "addGit — reuse existing repo"

REPO4="${PREFIX}_4"
addGit --path "$TMP_DIR" --repo "$REPO4" nginx.conf 2>/dev/null
echo "worker_processes 4;" >> "$TMP_DIR/nginx.conf"
addGit --repo "$REPO4" nginx.conf 2>/dev/null
CI_TEST_assert_eq "second call exits 0"    "0" "$?"
CI_TEST_assert_eq "two commits total"      "2" "$(_commit_count "$REPO4")"

out=$(addGit --repo "$REPO4" nginx.conf 2>&1)
CI_TEST_assert_contains "nothing to commit when file unchanged" "Nothing" "$out"

# ── Auto-detect by absolute path ─────────────────────────────────────────────
CI_TEST_suite "addGit — auto-detect repo from file path"

# Use isolated dir so only one repo matches this path
AUTODETECT_DIR="$(mktemp -d)"
echo "original" > "$AUTODETECT_DIR/nginx.conf"
REPO5="${PREFIX}_5"
addGit --path "$AUTODETECT_DIR" --repo "$REPO5" nginx.conf 2>/dev/null
echo "# auto-detect test" >> "$AUTODETECT_DIR/nginx.conf"

out=$(addGit "$AUTODETECT_DIR/nginx.conf" 2>&1)
CI_TEST_assert_eq       "auto-detect exits 0"      "0" "$?"
CI_TEST_assert_contains "auto-detect prints repo"  "Auto-detected" "$out"
CI_TEST_assert_eq       "auto-detect commits"      "2" "$(_commit_count "$REPO5")"
/bin/rm -rf "$AUTODETECT_DIR"

# ── Custom comment ────────────────────────────────────────────────────────────
CI_TEST_suite "addGit — custom commit message"

REPO6="${PREFIX}_6"
addGit --path "$TMP_DIR" --repo "$REPO6" nginx.conf 2>/dev/null
echo "change" >> "$TMP_DIR/nginx.conf"
addGit --repo "$REPO6" --comment "my custom comment" nginx.conf 2>/dev/null
last_msg="$(_commit_log "$REPO6" | head -1)"
CI_TEST_assert_contains "--comment used as commit message" "my custom comment" "$last_msg"

# ── Custom branch ─────────────────────────────────────────────────────────────
CI_TEST_suite "addGit — custom branch"

REPO7="${PREFIX}_7"
addGit --path "$TMP_DIR" --repo "$REPO7" --branch dev nginx.conf 2>/dev/null
cur_branch="$(git -C "$(_repo_path "$REPO7")" rev-parse --abbrev-ref HEAD 2>/dev/null)"
CI_TEST_assert_eq "--branch sets correct branch" "dev" "$cur_branch"

# ── --diff mode ───────────────────────────────────────────────────────────────
CI_TEST_suite "addGit — --diff mode"

REPO8="${PREFIX}_8"
echo "original" > "$TMP_DIR/nginx.conf"
addGit --path "$TMP_DIR" --repo "$REPO8" nginx.conf 2>/dev/null
echo "modified" > "$TMP_DIR/nginx.conf"

out=$(addGit --repo "$REPO8" --diff nginx.conf 2>&1)
CI_TEST_assert_eq "--diff exits 0"                   "0" "$?"
CI_TEST_assert_contains "--diff shows current path"  "$TMP_DIR/nginx.conf" "$out"
CI_TEST_assert_contains "--diff shows tracked path"  "$(_repo_path "$REPO8")" "$out"

# --diff should NOT create a new commit
CI_TEST_assert_eq "--diff does not commit" "1" "$(_commit_count "$REPO8")"

# --diff on non-existent repo → error
addGit --repo "nonexistent_${PREFIX}" --diff nginx.conf 2>/dev/null
CI_TEST_assert_eq "--diff on missing repo → exit 1" "1" "$?"

# --diff with no files → error
addGit --repo "$REPO8" --diff 2>/dev/null
CI_TEST_assert_eq "--diff without files → exit 1" "1" "$?"

# ── Missing --path for new repo ───────────────────────────────────────────────
CI_TEST_suite "addGit — error cases"

addGit --repo "newrepo_${PREFIX}" nginx.conf 2>/dev/null
CI_TEST_assert_eq "--repo without --path on new repo → exit 1" "1" "$?"

CI_TEST_summary
exit $?
