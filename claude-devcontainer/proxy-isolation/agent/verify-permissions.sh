#!/bin/bash
# Verify filesystem permissions are enforced correctly
# Run this script inside the agent container as the node user
# Analogous to verify-proxy.sh for network isolation

set -euo pipefail

echo "============================================"
echo "Filesystem Permission Verification"
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
    ((PASSED++))
}

fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    ((FAILED++))
}

warn() {
    echo -e "${YELLOW}⚠ WARN${NC}: $1"
}

# Check if we're running as the correct user (should be node, not root)
echo "1. Checking execution context..."
CURRENT_USER=$(whoami)
if [ "$CURRENT_USER" = "node" ]; then
    pass "Running as node user"
else
    warn "Running as $CURRENT_USER (expected node)"
fi

# Check if permissions file was loaded
PERMISSIONS_FILE="${PERMISSIONS_FILE:-/etc/agent-permissions.json}"
if [ -f "$PERMISSIONS_FILE" ]; then
    RULE_COUNT=$(jq '.rules | length' "$PERMISSIONS_FILE")
    pass "Permissions file loaded ($RULE_COUNT rules)"
else
    fail "Permissions file not found at $PERMISSIONS_FILE"
    echo "  Cannot verify permissions without config file"
    exit 1
fi
echo ""

# Test readable paths
echo "2. Testing readable paths (should succeed)..."

if [ -r /workspace ]; then
    pass "/workspace is readable"
else
    fail "/workspace is not readable"
fi

if ls /usr/bin >/dev/null 2>&1; then
    pass "/usr/bin is readable"
else
    fail "/usr/bin is not readable"
fi

if [ -r /etc/hostname ]; then
    pass "/etc/hostname is readable"
else
    fail "/etc/hostname is not readable"
fi
echo ""

# Test writable paths
echo "3. Testing writable paths (should succeed)..."

WORKSPACE_TEST_FILE="/workspace/.permissions-test-$$"
if touch "$WORKSPACE_TEST_FILE" 2>/dev/null; then
    rm -f "$WORKSPACE_TEST_FILE"
    pass "/workspace is writable"
else
    fail "/workspace is not writable"
fi

TMP_TEST_FILE="/tmp/.permissions-test-$$"
if touch "$TMP_TEST_FILE" 2>/dev/null; then
    rm -f "$TMP_TEST_FILE"
    pass "/tmp is writable"
else
    fail "/tmp is not writable"
fi

CLAUDE_DIR="/home/node/.claude"
if [ -d "$CLAUDE_DIR" ]; then
    CLAUDE_TEST_FILE="$CLAUDE_DIR/.permissions-test-$$"
    if touch "$CLAUDE_TEST_FILE" 2>/dev/null; then
        rm -f "$CLAUDE_TEST_FILE"
        pass "/home/node/.claude is writable"
    else
        fail "/home/node/.claude is not writable"
    fi
fi
echo ""

# Test denied paths
echo "4. Testing denied paths (should fail)..."

if touch /etc/test-write-$$ 2>/dev/null; then
    rm -f /etc/test-write-$$
    fail "/etc is writable (should be read-only)"
else
    pass "/etc is not writable"
fi

if touch /usr/test-write-$$ 2>/dev/null; then
    rm -f /usr/test-write-$$
    fail "/usr is writable (should be read-only)"
else
    pass "/usr is not writable"
fi

if cat /etc/shadow >/dev/null 2>&1; then
    fail "/etc/shadow is readable (should be denied)"
else
    pass "/etc/shadow is not readable"
fi

if ls /root >/dev/null 2>&1; then
    fail "/root is accessible (should be denied)"
else
    pass "/root is not accessible"
fi
echo ""

# Test that ACLs are actually applied (if getfacl is available)
echo "5. Checking ACL presence..."
if command -v getfacl >/dev/null 2>&1; then
    if getfacl /workspace 2>/dev/null | grep -q "user:node"; then
        pass "ACLs are set on /workspace"
    else
        warn "No explicit ACLs found on /workspace (may use standard permissions)"
    fi
else
    warn "getfacl not available, cannot inspect ACLs directly"
fi
echo ""

# Summary
echo "============================================"
echo "Summary: $PASSED passed, $FAILED failed"
echo "============================================"

if [ $FAILED -gt 0 ]; then
    echo ""
    echo "Some tests failed. Please check:"
    echo "  1. The entrypoint.sh ran correctly"
    echo "  2. permissions.json is properly configured"
    echo "  3. The filesystem supports POSIX ACLs"
    exit 1
else
    echo ""
    echo "All tests passed! Filesystem permissions are enforced correctly."
    exit 0
fi
