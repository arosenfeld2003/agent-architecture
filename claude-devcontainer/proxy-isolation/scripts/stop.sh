#!/bin/bash
# Stop the proxy-isolated agent environment
# Usage: ./scripts/stop.sh [--volumes]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

if [[ "${1:-}" == "--volumes" ]]; then
    echo "Stopping environment and removing volumes..."
    docker compose down -v
else
    echo "Stopping environment (keeping volumes)..."
    docker compose down
fi

echo "Environment stopped."
