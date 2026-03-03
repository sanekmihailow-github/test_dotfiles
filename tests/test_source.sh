#!/usr/bin/env bash
# Test: all shell source files load without errors

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$TESTS_DIR")"
source "$TESTS_DIR/helpers.sh"

CI_TEST_suite "Source files load without errors"

SHELL_SOURCE="$REPO_DIR/.shell_source"

for f in functions alias defaults exports git prompt prompt_root; do
    filepath="$SHELL_SOURCE/$f"
    if [ ! -f "$filepath" ]; then
        CI_TEST_skip "$f — file not found"
        continue
    fi
    bash --norc -c "source '$filepath'" 2>/dev/null
    CI_TEST_assert_eq "source $f" "0" "$?"
done

CI_TEST_suite "Install helper scripts load without errors"

for f in "$REPO_DIR/functions.sh" "$REPO_DIR/dot_install.sh" "$REPO_DIR/dot_uninstall.sh"; do
    name="$(basename "$f")"
    bash -n "$f" 2>/dev/null
    CI_TEST_assert_eq "bash -n $name" "0" "$?"
done

CI_TEST_suite "Python scripts compile without errors"

for f in colorex grc grcat; do
    filepath="$REPO_DIR/.local/bin/$f"
    if ! command -v python3 >/dev/null 2>&1; then
        CI_TEST_skip "$f — python3 not found"
        continue
    fi
    if [ ! -f "$filepath" ]; then
        CI_TEST_skip "$f — file not found"
        continue
    fi
    python3 -m py_compile "$filepath" 2>/dev/null
    CI_TEST_assert_eq "py_compile $f" "0" "$?"
done

CI_TEST_summary
exit $?
