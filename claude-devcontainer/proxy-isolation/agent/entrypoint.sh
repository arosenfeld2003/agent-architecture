#!/bin/bash
# Entrypoint script for AI Agent container
# Applies filesystem permissions from permissions.json using POSIX ACLs,
# then drops privileges to the node user.
#
# This script runs as root. It reads a JSON permissions config,
# applies setfacl rules for the node user, then exec's the CMD as node.

set -euo pipefail

PERMISSIONS_FILE="${PERMISSIONS_FILE:-/etc/agent-permissions.json}"
TARGET_USER="node"

# If no permissions file exists, just run as node without restrictions
if [ ! -f "$PERMISSIONS_FILE" ]; then
    echo "[entrypoint] No permissions file found at $PERMISSIONS_FILE"
    echo "[entrypoint] Running without filesystem restrictions"
    exec gosu "$TARGET_USER" "$@"
fi

echo "[entrypoint] Applying filesystem permissions from $PERMISSIONS_FILE"

# Validate JSON
if ! jq empty "$PERMISSIONS_FILE" 2>/dev/null; then
    echo "[entrypoint] ERROR: Invalid JSON in $PERMISSIONS_FILE"
    exit 1
fi

DEFAULT_POLICY=$(jq -r '.defaultPolicy // "deny"' "$PERMISSIONS_FILE")
echo "[entrypoint] Default policy: $DEFAULT_POLICY"

# Track counts for summary
APPLIED=0
SKIPPED=0
ERRORS=0

# Process each rule
jq -c '.rules[]' "$PERMISSIONS_FILE" | while read -r rule; do
    path=$(echo "$rule" | jq -r '.path')
    access=$(echo "$rule" | jq -r '.access')
    recursive=$(echo "$rule" | jq -r '.recursive // true')

    # Skip paths that don't exist (e.g., /proc may not be mounted yet)
    if [ ! -e "$path" ]; then
        echo "  SKIP: $path (does not exist)"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    # Determine ACL permission string
    case "$access" in
        read)
            # Read + execute for directories (needed for ls/traversal), read for files
            if [ -d "$path" ]; then
                acl_perm="rx"
            else
                acl_perm="r"
            fi
            ;;
        write|readwrite)
            if [ -d "$path" ]; then
                acl_perm="rwx"
            else
                acl_perm="rw"
            fi
            ;;
        none)
            acl_perm="---"
            ;;
        *)
            echo "  ERROR: Unknown access level '$access' for $path"
            ERRORS=$((ERRORS + 1))
            continue
            ;;
    esac

    # Apply ACL
    if [ "$recursive" = "true" ] && [ -d "$path" ]; then
        echo "  $path -> $access (recursive)"
        if setfacl -R -m "u:${TARGET_USER}:${acl_perm}" "$path" 2>/dev/null; then
            # Also set default ACL so new files inherit the permission
            setfacl -R -d -m "u:${TARGET_USER}:${acl_perm}" "$path" 2>/dev/null || true
            APPLIED=$((APPLIED + 1))
        else
            echo "  WARN: Could not apply ACL to $path (filesystem may not support ACLs)"
            ERRORS=$((ERRORS + 1))
        fi
    else
        echo "  $path -> $access"
        if setfacl -m "u:${TARGET_USER}:${acl_perm}" "$path" 2>/dev/null; then
            APPLIED=$((APPLIED + 1))
        else
            echo "  WARN: Could not apply ACL to $path (filesystem may not support ACLs)"
            ERRORS=$((ERRORS + 1))
        fi
    fi
done

echo "[entrypoint] Permissions applied. Dropping to $TARGET_USER user."
exec gosu "$TARGET_USER" "$@"
