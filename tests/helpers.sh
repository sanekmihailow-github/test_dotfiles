#!/usr/bin/env bash
# CI test framework — all names prefixed with CI_TEST_ to avoid conflicts

CI_TEST_PASS=0
CI_TEST_FAIL=0
CI_TEST_SKIP=0

_CI_G='\033[0;32m'
_CI_R='\033[0;31m'
_CI_Y='\033[0;33m'
_CI_B='\033[0;34m'
_CI_W='\033[1;37m'
_CI_0='\033[0m'

CI_TEST_pass() { CI_TEST_PASS=$((CI_TEST_PASS+1)); echo -e "${_CI_G}  PASS${_CI_0} $1"; }
CI_TEST_fail() { CI_TEST_FAIL=$((CI_TEST_FAIL+1)); echo -e "${_CI_R}  FAIL${_CI_0} $1"; [ -n "$2" ] && echo -e "       ${_CI_Y}$2${_CI_0}"; }
CI_TEST_skip() { CI_TEST_SKIP=$((CI_TEST_SKIP+1)); echo -e "${_CI_Y}  SKIP${_CI_0} $1"; }

CI_TEST_assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        CI_TEST_pass "$desc"
    else
        CI_TEST_fail "$desc" "expected: '$expected'  got: '$actual'"
    fi
}

CI_TEST_assert_ne() {
    local desc="$1" unexpected="$2" actual="$3"
    if [ "$unexpected" != "$actual" ]; then
        CI_TEST_pass "$desc"
    else
        CI_TEST_fail "$desc" "unexpected value: '$actual'"
    fi
}

CI_TEST_assert_file_exists() {
    if [ -f "$2" ]; then CI_TEST_pass "$1"; else CI_TEST_fail "$1" "file not found: $2"; fi
}

CI_TEST_assert_dir_exists() {
    if [ -d "$2" ]; then CI_TEST_pass "$1"; else CI_TEST_fail "$1" "dir not found: $2"; fi
}

CI_TEST_assert_file_not_exists() {
    if [ ! -f "$2" ]; then CI_TEST_pass "$1"; else CI_TEST_fail "$1" "file should not exist: $2"; fi
}

CI_TEST_assert_contains() {
    local desc="$1" pattern="$2" string="$3"
    if echo "$string" | grep -q "$pattern"; then
        CI_TEST_pass "$desc"
    else
        CI_TEST_fail "$desc" "pattern '$pattern' not found in output"
    fi
}

CI_TEST_assert_exit_ok() {
    local desc="$1"; shift
    "$@" >/dev/null 2>&1
    if [ "$?" -eq 0 ]; then CI_TEST_pass "$desc"; else CI_TEST_fail "$desc" "command exited non-zero: $*"; fi
}

CI_TEST_assert_exit_fail() {
    local desc="$1"; shift
    "$@" >/dev/null 2>&1
    if [ "$?" -ne 0 ]; then CI_TEST_pass "$desc"; else CI_TEST_fail "$desc" "command should have failed: $*"; fi
}

CI_TEST_suite() {
    echo -e "\n${_CI_W}=== $1 ===${_CI_0}"
}

CI_TEST_summary() {
    echo -e "\n${_CI_B}Results:${_CI_0} ${_CI_G}${CI_TEST_PASS} passed${_CI_0}, ${_CI_R}${CI_TEST_FAIL} failed${_CI_0}, ${_CI_Y}${CI_TEST_SKIP} skipped${_CI_0}"
    [ "$CI_TEST_FAIL" -gt 0 ] && return 1 || return 0
}
