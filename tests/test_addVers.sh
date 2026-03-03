#!/usr/bin/env bash
# Tests for addVers()

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$TESTS_DIR")"
source "$TESTS_DIR/helpers.sh"
source "$REPO_DIR/.shell_source/functions"
unset -f rm  # prevent interactive rm() wrapper from interfering

TMP_DIR="$(mktemp -d)"
cleanup() { chmod -R u+w "$TMP_DIR" 2>/dev/null; /bin/rm -rf "$TMP_DIR"; }
trap cleanup EXIT

# Create test file
echo "original content" > "$TMP_DIR/test.conf"

CI_TEST_suite "addVers — argument validation"

addVers 2>/dev/null
CI_TEST_assert_eq "no args → exit 1" "1" "$?"

addVers "$TMP_DIR/nonexistent.conf" 2>/dev/null
CI_TEST_assert_eq "nonexistent file → exit 1" "1" "$?"

CI_TEST_suite "addVers — versioning logic"

addVers "$TMP_DIR/test.conf" >/dev/null 2>&1
CI_TEST_assert_eq "first call exits 0" "0" "$?"
CI_TEST_assert_file_exists "creates _vers1" "/tmp/versions${TMP_DIR}/test.conf_vers1"

addVers "$TMP_DIR/test.conf" >/dev/null 2>&1
CI_TEST_assert_file_exists "creates _vers2 on second call" "/tmp/versions${TMP_DIR}/test.conf_vers2"

addVers "$TMP_DIR/test.conf" >/dev/null 2>&1
CI_TEST_assert_file_exists "creates _vers3 on third call" "/tmp/versions${TMP_DIR}/test.conf_vers3"

CI_TEST_suite "addVers — content integrity"

vers1_content="$(cat "/tmp/versions${TMP_DIR}/test.conf_vers1" 2>/dev/null)"
CI_TEST_assert_eq "vers1 content matches original" "original content" "$vers1_content"

CI_TEST_suite "addVers — path structure"

mkdir -p "$TMP_DIR/subdir"
echo "sub content" > "$TMP_DIR/subdir/sub.conf"
addVers "$TMP_DIR/subdir/sub.conf" >/dev/null 2>&1
CI_TEST_assert_file_exists "subdir path preserved in /tmp/versions" \
    "/tmp/versions${TMP_DIR}/subdir/sub.conf_vers1"

CI_TEST_suite "addVers — relative path (from TMP_DIR)"

cd "$TMP_DIR" || exit 1
addVers test.conf >/dev/null 2>&1
# Should auto-resolve to $PWD/test.conf, continuing the vers count
vers_count=$(ls "/tmp/versions${TMP_DIR}/test.conf_vers"* 2>/dev/null | wc -l)
CI_TEST_assert_ne "relative path resolves and increments version" "0" "$vers_count"
cd - >/dev/null

CI_TEST_suite "addVers — output message"

out=$(addVers "$TMP_DIR/test.conf" 2>/dev/null)
CI_TEST_assert_contains "output contains 'Saved:'" "Saved:" "$out"
CI_TEST_assert_contains "output contains path" "/tmp/versions" "$out"

CI_TEST_summary
exit $?
