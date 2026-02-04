#!/bin/bash
# Verify proxy connectivity and isolation
# Run this script to ensure the network isolation is working correctly

set -euo pipefail

echo "============================================"
echo "Proxy Network Isolation Verification"
echo "============================================"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

# Check proxy environment variables
echo "1. Checking proxy environment variables..."
if [ -n "${HTTP_PROXY:-}" ] && [ -n "${HTTPS_PROXY:-}" ]; then
    pass "Proxy environment variables are set"
    echo "   HTTP_PROXY=$HTTP_PROXY"
    echo "   HTTPS_PROXY=$HTTPS_PROXY"
else
    fail "Proxy environment variables not set"
fi
echo ""

# Test allowed domains
echo "2. Testing allowed domains (should succeed)..."

# GitHub
if curl -s --connect-timeout 10 -o /dev/null -w "%{http_code}" https://api.github.com/zen | grep -q "200"; then
    pass "GitHub API accessible"
else
    fail "Cannot reach GitHub API"
fi

# Anthropic
if curl -s --connect-timeout 10 -o /dev/null -w "%{http_code}" https://api.anthropic.com 2>/dev/null | grep -qE "200|401|403"; then
    pass "Anthropic API accessible (may return auth error, but network works)"
else
    fail "Cannot reach Anthropic API"
fi

# npm registry
if curl -s --connect-timeout 10 -o /dev/null -w "%{http_code}" https://registry.npmjs.org/-/ping | grep -q "200"; then
    pass "npm registry accessible"
else
    fail "Cannot reach npm registry"
fi

echo ""

# Test blocked domains
echo "3. Testing blocked domains (should fail)..."

# Example.com (should be blocked)
if curl -s --connect-timeout 10 https://example.com >/dev/null 2>&1; then
    fail "example.com is accessible (should be blocked)"
else
    pass "example.com is blocked"
fi

# Random external site
if curl -s --connect-timeout 10 https://httpbin.org/get >/dev/null 2>&1; then
    fail "httpbin.org is accessible (should be blocked)"
else
    pass "httpbin.org is blocked"
fi

# Google (should be blocked unless explicitly allowed)
if curl -s --connect-timeout 10 https://www.google.com >/dev/null 2>&1; then
    fail "google.com is accessible (should be blocked)"
else
    pass "google.com is blocked"
fi

echo ""

# Test Git operations
echo "4. Testing Git operations..."
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

if git clone --depth 1 https://github.com/octocat/Hello-World.git >/dev/null 2>&1; then
    pass "Git clone over HTTPS works"
    rm -rf Hello-World
else
    fail "Git clone over HTTPS failed"
fi

cd - >/dev/null
rm -rf "$TEMP_DIR"

echo ""

# Summary
echo "============================================"
echo "Summary: $PASSED passed, $FAILED failed"
echo "============================================"

if [ $FAILED -gt 0 ]; then
    echo ""
    echo "Some tests failed. Please check:"
    echo "  1. Proxy container is running"
    echo "  2. Network isolation is properly configured"
    echo "  3. Allowlist includes required domains"
    exit 1
else
    echo ""
    echo "All tests passed! Network isolation is working correctly."
    exit 0
fi
