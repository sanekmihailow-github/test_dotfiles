#!/usr/bin/env bash
# Tests for extract()

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$TESTS_DIR")"
source "$TESTS_DIR/helpers.sh"
source "$REPO_DIR/.shell_source/functions"
unset -f rm  # prevent interactive rm() wrapper

TMP_DIR="$(mktemp -d)"
ARCHIVES_DIR="$TMP_DIR/archives"
EXTRACT_DIR="$TMP_DIR/extracted"
mkdir -p "$ARCHIVES_DIR" "$EXTRACT_DIR"

cleanup() { /bin/rm -rf "$TMP_DIR"; }
trap cleanup EXIT

# Create source file for archiving
echo "test file content" > "$TMP_DIR/testfile.txt"

# Helper: run extract in a clean subdir so files don't overlap between tests
_extract_in_dir() {
    local archive="$1"
    local dest="$EXTRACT_DIR/$(basename "$archive" | tr '.' '_')"
    mkdir -p "$dest"
    cp "$archive" "$dest/"
    cd "$dest" || return 1
    extract "$(basename "$archive")" >/dev/null 2>&1
    local rc=$?
    cd - >/dev/null
    return $rc
}

# ── Argument validation ───────────────────────────────────────────────────────
CI_TEST_suite "extract — argument validation"

extract 2>/dev/null
CI_TEST_assert_eq "no args → exit 1" "1" "$?"

extract "$TMP_DIR/nonexistent.tar.gz" 2>/dev/null
CI_TEST_assert_eq "nonexistent file → exit 1" "1" "$?"

extract "$TMP_DIR/testfile.txt" 2>/dev/null
CI_TEST_assert_eq "unknown extension → exit 1" "1" "$?"

# ── tar.gz ────────────────────────────────────────────────────────────────────
CI_TEST_suite "extract — .tar.gz"

tar czf "$ARCHIVES_DIR/test.tar.gz" -C "$TMP_DIR" testfile.txt 2>/dev/null
if [ -f "$ARCHIVES_DIR/test.tar.gz" ]; then
    _extract_in_dir "$ARCHIVES_DIR/test.tar.gz"
    CI_TEST_assert_eq ".tar.gz extraction exits 0" "0" "$?"
    CI_TEST_assert_file_exists ".tar.gz file extracted" \
        "$EXTRACT_DIR/test_tar_gz/testfile.txt"
else
    CI_TEST_skip ".tar.gz — tar not available"
fi

# ── tar.bz2 ───────────────────────────────────────────────────────────────────
CI_TEST_suite "extract — .tar.bz2"

if command -v bzip2 >/dev/null 2>&1; then
    tar cjf "$ARCHIVES_DIR/test.tar.bz2" -C "$TMP_DIR" testfile.txt 2>/dev/null
    _extract_in_dir "$ARCHIVES_DIR/test.tar.bz2"
    CI_TEST_assert_eq ".tar.bz2 extraction exits 0" "0" "$?"
    CI_TEST_assert_file_exists ".tar.bz2 file extracted" \
        "$EXTRACT_DIR/test_tar_bz2/testfile.txt"
else
    CI_TEST_skip ".tar.bz2 — bzip2 not available"
fi

# ── .gz (single file) ────────────────────────────────────────────────────────
CI_TEST_suite "extract — .gz (single file)"

if command -v gzip >/dev/null 2>&1; then
    cp "$TMP_DIR/testfile.txt" "$ARCHIVES_DIR/testfile.txt"
    gzip "$ARCHIVES_DIR/testfile.txt" 2>/dev/null
    _extract_in_dir "$ARCHIVES_DIR/testfile.txt.gz"
    CI_TEST_assert_eq ".gz extraction exits 0" "0" "$?"
else
    CI_TEST_skip ".gz — gzip not available"
fi

# ── .zip ──────────────────────────────────────────────────────────────────────
CI_TEST_suite "extract — .zip"

if command -v zip >/dev/null 2>&1; then
    ( cd "$TMP_DIR" && zip "$ARCHIVES_DIR/test.zip" testfile.txt >/dev/null 2>&1 )
    _extract_in_dir "$ARCHIVES_DIR/test.zip"
    CI_TEST_assert_eq ".zip extraction exits 0" "0" "$?"
    CI_TEST_assert_file_exists ".zip file extracted" \
        "$EXTRACT_DIR/test_zip/testfile.txt"
else
    CI_TEST_skip ".zip — zip not available"
fi

# ── .tar.zst ─────────────────────────────────────────────────────────────────
CI_TEST_suite "extract — .tar.zst"

if command -v zstd >/dev/null 2>&1; then
    tar -I zstd -cf "$ARCHIVES_DIR/test.tar.zst" -C "$TMP_DIR" testfile.txt 2>/dev/null
    _extract_in_dir "$ARCHIVES_DIR/test.tar.zst"
    CI_TEST_assert_eq ".tar.zst extraction exits 0" "0" "$?"
    CI_TEST_assert_file_exists ".tar.zst file extracted" \
        "$EXTRACT_DIR/test_tar_zst/testfile.txt"
else
    CI_TEST_skip ".tar.zst — zstd not available"
fi

CI_TEST_summary
exit $?
