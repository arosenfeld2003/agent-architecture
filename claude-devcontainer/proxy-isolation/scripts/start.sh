#!/bin/bash
# Start the proxy-isolated agent environment
# Usage: ./scripts/start.sh [workspace_path]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Default workspace path
WORKSPACE_PATH="${1:-$PROJECT_DIR/../workspace}"

# Ensure workspace directory exists
mkdir -p "$WORKSPACE_PATH"

# Export for docker-compose
export WORKSPACE_PATH
export TZ="${TZ:-America/Los_Angeles}"
export CLAUDE_CODE_VERSION="${CLAUDE_CODE_VERSION:-latest}"

# Validate and export permissions file
PERMISSIONS_FILE="${PERMISSIONS_FILE:-$PROJECT_DIR/agent/permissions.json}"
if [ -f "$PERMISSIONS_FILE" ]; then
    if ! jq empty "$PERMISSIONS_FILE" 2>/dev/null; then
        echo "ERROR: Invalid JSON in permissions file: $PERMISSIONS_FILE"
        exit 1
    fi
    RULE_COUNT=$(jq '.rules | length' "$PERMISSIONS_FILE")
else
    RULE_COUNT=0
    echo "WARNING: No permissions file found at $PERMISSIONS_FILE"
    echo "  Agent will run without filesystem restrictions"
fi
export PERMISSIONS_FILE

echo "Starting proxy-isolated agent environment..."
echo "  Workspace:   $WORKSPACE_PATH"
echo "  Timezone:    $TZ"
echo "  Permissions: $PERMISSIONS_FILE ($RULE_COUNT rules)"
echo ""

cd "$PROJECT_DIR"

# Build and start services
docker compose build
docker compose up -d

# Wait for services to be healthy
echo "Waiting for services to be ready..."
sleep 5

# Check proxy health
if docker compose exec -T proxy squid -k check 2>/dev/null; then
    echo "✓ Proxy is healthy"
else
    echo "✗ Proxy health check failed"
    docker compose logs proxy
    exit 1
fi

echo ""
echo "============================================"
echo "Environment is ready!"
echo ""
echo "To enter the agent container:"
echo "  docker compose exec claude zsh"
echo ""
echo "To verify network isolation:"
echo "  docker compose exec claude /usr/local/bin/verify-proxy.sh"
echo ""
echo "To verify filesystem permissions:"
echo "  docker compose exec claude /usr/local/bin/verify-permissions.sh"
echo ""
echo "To view proxy logs:"
echo "  docker compose logs -f proxy"
echo ""
echo "To stop the environment:"
echo "  docker compose down"
echo "============================================"
