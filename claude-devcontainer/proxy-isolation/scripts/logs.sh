#!/bin/bash
# View proxy access logs for auditing
# Usage: ./scripts/logs.sh [--follow] [--tail N]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

FOLLOW=""
TAIL=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --follow|-f)
            FOLLOW="-f"
            shift
            ;;
        --tail|-n)
            TAIL="--tail $2"
            shift 2
            ;;
        *)
            echo "Usage: $0 [--follow|-f] [--tail|-n N]"
            exit 1
            ;;
    esac
done

echo "Proxy Access Logs"
echo "================="
echo ""
# shellcheck disable=SC2086
docker compose logs $FOLLOW $TAIL proxy
