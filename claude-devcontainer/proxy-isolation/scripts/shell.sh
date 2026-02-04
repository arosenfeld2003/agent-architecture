#!/bin/bash
# Enter a shell in the agent container
# Usage: ./scripts/shell.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "Entering agent container..."
docker compose exec claude zsh
