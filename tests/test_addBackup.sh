#!/usr/bin/env bash
# Tests for addBackup()

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$TESTS_DIR")"
source "$TESTS_DIR/helpers.sh"
source "$REPO_DIR/.shell_source/functions"
unset -f rm  # prevent interactive rm() wrapper

TMP_DIR="$(mktemp -d)"
cleanup() {
    # Make all files writable before removal (addBackup sets chmod 0444)
    find "$TMP_DIR" -type f -exec chmod u+w {} \; 2>/dev/null
    /bin/rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# ── Argument validation ───────────────────────────────────────────────────────
CI_TEST_suite "addBackup — argument validation"

addBackup 2>/dev/null
CI_TEST_assert_eq "no args → exit 1" "1" "$?"

addBackup "$TMP_DIR/nonexistent.conf" 2>/dev/null
CI_TEST_assert_eq "nonexistent file → exit 1" "1" "$?"

# ── File backup ───────────────────────────────────────────────────────────────
CI_TEST_suite "addBackup — file backup"

echo "original content" > "$TMP_DIR/test.conf"

# Run from TMP_DIR since addBackup uses $PWD
cd "$TMP_DIR" || exit 1
addBackup test.conf 2>/dev/null
CI_TEST_assert_file_exists "first backup created (.bak1.bak)" "$TMP_DIR/test.conf.bak1.bak"

# Content should match original
bak_content="$(cat "$TMP_DIR/test.conf.bak1.bak" 2>/dev/null | tail -1)"
CI_TEST_assert_eq "backup content matches original" "original content" "$bak_content"

# File should be read-only (chmod 0444)
perms="$(stat -c '%a' "$TMP_DIR/test.conf.bak1.bak" 2>/dev/null)"
CI_TEST_assert_eq "backup is read-only (0444)" "444" "$perms"

# Second backup
echo "modified content" > "$TMP_DIR/test.conf"
addBackup test.conf 2>/dev/null
CI_TEST_assert_file_exists "second backup created (.bak2.bak)" "$TMP_DIR/test.conf.bak2.bak"

# Third backup
addBackup test.conf 2>/dev/null
CI_TEST_assert_file_exists "third backup created (.bak3.bak)" "$TMP_DIR/test.conf.bak3.bak"

# ── Directory backup ──────────────────────────────────────────────────────────
CI_TEST_suite "addBackup — directory backup"

mkdir -p "$TMP_DIR/mydir"
echo "file1" > "$TMP_DIR/mydir/file1.txt"
echo "file2" > "$TMP_DIR/mydir/file2.txt"

cd "$TMP_DIR" || exit 1
addBackup mydir 2>/dev/null

# Should create .tar.gz or .tar.zst
archive_gz="$TMP_DIR/mydir_1.tar.gz"
archive_zst="$TMP_DIR/mydir_1.tar.zst"
if [ -f "$archive_gz" ] || [ -f "$archive_zst" ]; then
    CI_TEST_pass "directory backup archive created (.tar.gz or .tar.zst)"
else
    CI_TEST_fail "directory backup archive created (.tar.gz or .tar.zst)" \
        "neither $archive_gz nor $archive_zst found"
fi

# Second directory backup
addBackup mydir 2>/dev/null
archive2_gz="$TMP_DIR/mydir_2.tar.gz"
archive2_zst="$TMP_DIR/mydir_2.tar.zst"
if [ -f "$archive2_gz" ] || [ -f "$archive2_zst" ]; then
    CI_TEST_pass "second directory backup increments number"
else
    CI_TEST_fail "second directory backup increments number" \
        "neither _2.tar.gz nor _2.tar.zst found"
fi

cd - >/dev/null

CI_TEST_summary
exit $?
