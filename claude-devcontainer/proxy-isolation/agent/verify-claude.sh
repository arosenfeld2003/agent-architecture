#!/bin/bash
# Verify Claude Code works end-to-end inside the sandboxed container
# Run this script inside the agent container as the node user
#
# Authentication: set ANTHROPIC_API_KEY before starting the container.
# The OAuth browser flow does not work through Docker's TTY layer.

set -euo pipefail

echo "============================================"
echo "Claude Code Integration Test"
echo "============================================"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    PASSED=$((PASSED + 1))
}

fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    FAILED=$((FAILED + 1))
}

warn() {
    echo -e "${YELLOW}⚠ WARN${NC}: $1"
}

cleanup() {
    echo ""
    echo "Cleaning up test files..."
    rm -f /workspace/test.txt
    echo "Done."
}
trap cleanup EXIT

# -------------------------------------------------------
# 1. Check Claude Code is installed
# -------------------------------------------------------
echo "1. Checking Claude Code installation..."
if claude --version >/dev/null 2>&1; then
    CLAUDE_VERSION=$(claude --version 2>&1)
    pass "Claude Code is installed ($CLAUDE_VERSION)"
else
    fail "Claude Code is not installed or not in PATH"
    echo "  Cannot continue without Claude Code."
    exit 1
fi
echo ""

# -------------------------------------------------------
# 2. Authenticate with Claude
# -------------------------------------------------------
echo "2. Checking authentication..."

# Check for an API key (primary auth method for containers)
if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    pass "ANTHROPIC_API_KEY is set"
else
    fail "ANTHROPIC_API_KEY is not set"
    echo ""
    echo "  The OAuth browser flow does not work through Docker's TTY layer."
    echo "  Set your API key and restart the container:"
    echo ""
    echo "    # Get a key from https://console.anthropic.com/settings/keys"
    echo "    export ANTHROPIC_API_KEY=sk-ant-..."
    echo "    docker compose up -d --force-recreate claude"
    echo "    docker compose exec -u node claude /usr/local/bin/verify-claude.sh"
    echo ""
    exit 1
fi
echo ""

# -------------------------------------------------------
# 3. Verify Claude can respond
# -------------------------------------------------------
echo "3. Verifying Claude can respond..."
set +e
RESPONSE=$(claude -p "Reply with exactly: ok" 2>&1)
CLAUDE_EXIT=$?
set -e

if [ $CLAUDE_EXIT -eq 0 ]; then
    pass "Claude responded successfully"
else
    fail "Claude could not respond (exit=$CLAUDE_EXIT)"
    echo "  Response: $RESPONSE"
    echo "  Check that your ANTHROPIC_API_KEY is valid."
    exit 1
fi
echo ""

# -------------------------------------------------------
# 4. Sandboxed write test — allowed path
# -------------------------------------------------------
echo "4. Testing Claude can write to /workspace (allowed path)..."
rm -f /workspace/test.txt

claude -p "Write exactly the word 'hello' to the file /workspace/test.txt. Do not output anything else." --allowedTools "Bash" >/dev/null 2>&1
WRITE_EXIT=$?

if [ $WRITE_EXIT -eq 0 ] && [ -f /workspace/test.txt ]; then
    CONTENT=$(cat /workspace/test.txt)
    if echo "$CONTENT" | grep -q "hello"; then
        pass "Claude wrote to /workspace/test.txt successfully"
    else
        fail "/workspace/test.txt exists but does not contain 'hello' (got: $CONTENT)"
    fi
else
    fail "Claude could not write to /workspace/test.txt (exit=$WRITE_EXIT)"
fi
echo ""

# -------------------------------------------------------
# 5. Sandboxed write test — denied path
# -------------------------------------------------------
echo "5. Testing Claude cannot write to /etc (denied path)..."

claude -p "Write the word 'hack' to the file /etc/test.txt. Do not output anything else." --allowedTools "Bash" >/dev/null 2>&1 || true

if [ -f /etc/test.txt ]; then
    fail "/etc/test.txt was created — filesystem isolation is broken!"
    rm -f /etc/test.txt 2>/dev/null || true
else
    pass "/etc/test.txt was not created — write correctly denied"
fi
echo ""

# -------------------------------------------------------
# Summary
# -------------------------------------------------------
echo "============================================"
echo "Summary: $PASSED passed, $FAILED failed"
echo "============================================"

if [ $FAILED -gt 0 ]; then
    echo ""
    echo "Some tests failed. Please check:"
    echo "  1. Claude Code is installed and up to date"
    echo "  2. Your authentication credentials are valid"
    echo "  3. Filesystem permissions are correctly applied"
    exit 1
else
    echo ""
    echo "All tests passed! Claude Code works correctly inside the sandbox."
    exit 0
fi
