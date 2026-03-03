#!/usr/bin/env bash
# Run all test suites and print a combined summary

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_B='\033[0;34m'
_G='\033[0;32m'
_R='\033[0;31m'
_W='\033[1;37m'
_0='\033[0m'

TOTAL_FAIL=0
SUITES_RUN=0
SUITES_FAIL=0

run_suite() {
    local file="$1"
    local name
    name="$(basename "$file" .sh)"
    SUITES_RUN=$((SUITES_RUN+1))
    echo -e "\n${_W}━━━ ${name} ━━━${_0}"
    bash "$file"
    local rc=$?
    if [ "$rc" -ne 0 ]; then
        SUITES_FAIL=$((SUITES_FAIL+1))
        TOTAL_FAIL=$((TOTAL_FAIL+rc))
    fi
}

run_suite "$TESTS_DIR/test_source.sh"
run_suite "$TESTS_DIR/test_addVers.sh"
run_suite "$TESTS_DIR/test_addGit.sh"
run_suite "$TESTS_DIR/test_addBackup.sh"
run_suite "$TESTS_DIR/test_extract.sh"

echo -e "\n${_W}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${_0}"
echo -e "${_B}Suites:${_0} ${SUITES_RUN} total"

if [ "$TOTAL_FAIL" -eq 0 ]; then
    echo -e "${_G}All tests passed!${_0}"
else
    echo -e "${_R}${SUITES_FAIL} suite(s) had failures${_0}"
fi

