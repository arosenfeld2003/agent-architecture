# Sandboxed AI Coding Agent with Network + Filesystem Isolation

This directory contains a Docker Compose setup that provides **two layers of isolation** for AI coding agents:

1. **Network isolation** — Squid HTTP proxy as the only gateway to the internet, with a domain allowlist
2. **Filesystem isolation** — POSIX ACLs enforced at container startup via a declarative `permissions.json`

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                       Docker Environment                          │
│                                                                   │
│   ┌──────────────────────────────────┐                            │
│   │          AI Agent Container       │                            │
│   │                                   │                            │
│   │   ┌───────────────────────────┐   │                            │
│   │   │   Filesystem ACLs         │   │                            │
│   │   │   (permissions.json)      │   │                            │
│   │   │                           │   │                            │
│   │   │  /workspace    → rw       │   │     ┌─────────────────┐   │
│   │   │  /usr, /etc    → r        │   │     │   Squid Proxy   │   │
│   │   │  /root         → denied   │   ├────►│   (allowlist)   │──►│Internet
│   │   │  /etc/shadow   → denied   │   │     │                 │   │
│   │   └───────────────────────────┘   │     └─────────────────┘   │
│   │                                   │             │              │
│   └──────────────────────────────────┘             │              │
│              │                                      │              │
│          [isolated network]                [isolated + external]   │
│           (internal only)                    networks              │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘

Security Layers:
  Layer 1: Docker internal network — no direct internet access
  Layer 2: Squid proxy — domain allowlist (proxy/allowlist.txt)
  Layer 3: Filesystem ACLs — path-based read/write control (agent/permissions.json)
```

**Key Points:**
- Agent container is on an **internal Docker network** with no direct internet access
- All HTTP/HTTPS traffic is routed through the Squid proxy via environment variables
- Proxy enforces a domain allowlist — only approved domains can be reached
- Filesystem access is controlled by POSIX ACLs applied at startup from `permissions.json`
- No `NET_ADMIN` or `NET_RAW` capabilities required
- Works with Docker Desktop 4.38+

## Quick Start

```bash
# Start the environment
./scripts/start.sh /path/to/your/workspace

# Enter the agent container
./scripts/shell.sh

# Verify network isolation is working
docker compose exec claude /usr/local/bin/verify-proxy.sh

# Verify filesystem permissions are enforced
docker compose exec claude /usr/local/bin/verify-permissions.sh

# View proxy logs
./scripts/logs.sh --follow

# Stop the environment
./scripts/stop.sh
```

## Testing Claude Code in the Container

To run Claude Code interactively inside the isolated container:

```bash
# Start the environment (if not already running)
docker compose up -d

# Run Claude Code interactively (-it flags required for input)
docker compose exec -it claude claude
```

On first run, Claude will prompt you to authenticate with your Anthropic API key.

### Verifying Proxy Isolation

Once inside Claude, test that the proxy is working:

**Allowed requests (should succeed):**
- Ask Claude to fetch from GitHub, npm, or Anthropic APIs
- Run: `npm install lodash`
- Run: `git clone https://github.com/octocat/Hello-World`

**Blocked requests (should fail):**
- Ask Claude to fetch `https://example.com`
- Ask Claude to fetch `https://httpbin.org/get`

### Monitoring Proxy Traffic

In a separate terminal, watch the proxy logs to see requests being allowed or denied:

```bash
# Real-time log of all requests
docker exec agent-proxy tail -f /var/log/squid/access.log
```

Log entries show:
- `TCP_TUNNEL/200` - Allowed HTTPS connection
- `TCP_DENIED/403` - Blocked by allowlist

## Filesystem Permissions

### How It Works

At container startup, an entrypoint script (`entrypoint.sh`) runs as root, reads `/etc/agent-permissions.json`, and applies POSIX ACLs using `setfacl` for the `node` user. It then drops privileges to `node` via `gosu` before executing the container's CMD.

The permissions file is mounted read-only (`:ro`) into the container, so the agent cannot modify its own restrictions.

### Permissions JSON Format

The permissions config (`agent/permissions.json`) defines which paths the agent can access:

```json
{
  "version": "1",
  "defaultPolicy": "deny",
  "rules": [
    { "path": "/workspace", "access": "readwrite", "recursive": true },
    { "path": "/workspace/.env", "access": "none" },
    { "path": "/home/node/.claude", "access": "readwrite", "recursive": true },
    { "path": "/tmp", "access": "readwrite", "recursive": true },
    { "path": "/usr", "access": "read", "recursive": true },
    { "path": "/etc", "access": "read", "recursive": true },
    { "path": "/root", "access": "none", "recursive": true },
    { "path": "/etc/shadow", "access": "none" }
  ]
}
```

| Field | Values | Description |
|-------|--------|-------------|
| `access` | `read`, `write`, `readwrite`, `none` | Permission level |
| `recursive` | `true` (default), `false` | Apply to all children |
| `defaultPolicy` | `deny`, `allow` | What happens to unlisted paths |

Rules are evaluated in order. More specific paths (e.g., `/workspace/.env`) should come after broader paths (e.g., `/workspace`) to override them.

### Using a Custom Permissions File

Pass your own permissions file via environment variable:

```bash
PERMISSIONS_FILE=/path/to/my-permissions.json ./scripts/start.sh /path/to/workspace
```

Or set it in your `.env` file:

```
PERMISSIONS_FILE=./custom-permissions.json
```

### Verifying Permissions

```bash
# Run the verification script inside the container
docker compose exec claude /usr/local/bin/verify-permissions.sh
```

This tests that readable paths are accessible, writable paths accept writes, and denied paths are blocked.

## Network Configuration

### Modifying the Allowlist

Edit `proxy/allowlist.txt` to add or remove allowed domains:

```text
# Allow a domain and all subdomains
.github.com

# Allow a specific domain only
api.anthropic.com
```

After editing, restart the proxy:

```bash
docker compose restart proxy
```

### Environment Variables

Set these before starting:

| Variable | Default | Description |
|----------|---------|-------------|
| `WORKSPACE_PATH` | `../workspace` | Path to mount as `/workspace` |
| `TZ` | `America/Los_Angeles` | Timezone |
| `CLAUDE_CODE_VERSION` | `latest` | Claude Code npm package version |
| `PERMISSIONS_FILE` | `./agent/permissions.json` | Filesystem permissions config |

### Proxy Configuration

The Squid configuration (`proxy/squid.conf`) can be customized:

- Change cache size
- Adjust logging format
- Modify connection timeouts
- Enable SSL inspection (requires CA cert setup)

## File Structure

```
proxy-isolation/
├── docker-compose.yml          # Main compose file
├── proxy/
│   ├── Dockerfile              # Squid proxy image
│   ├── squid.conf              # Squid configuration
│   └── allowlist.txt           # Allowed domains
├── agent/
│   ├── Dockerfile              # Agent container image
│   ├── entrypoint.sh           # Applies filesystem ACLs, drops to node user
│   ├── permissions.json        # Default filesystem permissions config
│   ├── verify-proxy.sh         # Network isolation verification
│   └── verify-permissions.sh   # Filesystem permission verification
├── scripts/
│   ├── start.sh                # Start environment
│   ├── stop.sh                 # Stop environment
│   ├── shell.sh                # Enter agent shell
│   └── logs.sh                 # View proxy logs
└── README.md                   # This file
```

## Demo: Testing Filesystem Isolation

Follow these steps to verify that the filesystem isolation layer is working correctly.

### Prerequisites

- Docker Desktop 4.38+ with Docker Compose
- Git

### 1. Clone and Start

```bash
git clone https://github.com/arosenfeld2003/agent-architecture.git
cd agent-architecture/claude-devcontainer/proxy-isolation
./scripts/start.sh ./workspace
```

### 2. Run the Automated Test Suite

```bash
docker compose exec -u node claude /usr/local/bin/verify-permissions.sh
```

This runs 12 checks covering readable, writable, and denied paths. All tests should pass.

### 3. Try It Interactively

```bash
docker compose exec -u node claude bash
```

**These should succeed:**

```bash
touch /workspace/hello.txt        # workspace is writable
ls /usr/bin                       # system binaries are readable
echo "test" > /tmp/test.txt       # tmp is writable
```

**These should be blocked:**

```bash
cat /etc/shadow                   # denied — sensitive file
ls /root                          # denied — root home directory
touch /etc/hacked                 # denied — /etc is read-only
touch /usr/bin/malicious          # denied — /usr is read-only
```

Exit the container when done:

```bash
exit
```

### 4. Clean Up

```bash
./scripts/stop.sh
```

### How It Works

All permissions are declared in `agent/permissions.json`. The entrypoint applies POSIX ACLs at startup via `setfacl`, then drops privileges to the `node` user. No code changes are needed to adjust the rules — just edit the JSON and restart the container.

## Comparison to iptables Approach

| Feature | iptables (old) | Proxy (new) |
|---------|---------------|-------------|
| Capabilities needed | NET_ADMIN, NET_RAW | None |
| DNS handling | Static at startup | Dynamic per-request |
| Filtering level | IP/port | Domain/URL |
| Audit logging | Limited | Full request logs |
| Multi-agent support | Per-agent config | Shared allowlist |
| Complexity | High | Medium |

## Troubleshooting

### Agent can't reach allowed domains

1. Check proxy is running: `docker compose ps`
2. Check proxy health: `docker compose exec proxy squid -k check`
3. View proxy logs: `docker compose logs proxy`
4. Verify domain is in allowlist: `grep domain proxy/allowlist.txt`

### "Connection refused" errors

The proxy may not be ready. Wait a few seconds or check:

```bash
docker compose logs proxy | tail -20
```

### Proxy cache issues

Clear the cache and restart:

```bash
docker compose down
docker volume rm proxy-isolation_proxy-cache
docker compose up -d
```

### Testing a new domain

Before adding to allowlist, test with curl:

```bash
# Inside agent container
curl -v https://new-domain.com
# Look for "403 Forbidden" (blocked) vs connection errors (network issue)
```

## Security Considerations

1. **HTTPS Tunneling**: By default, HTTPS traffic uses CONNECT tunneling. The proxy can filter by domain but cannot inspect encrypted content. For content inspection, enable SSL bump (requires CA certificate distribution).

2. **DNS Resolution**: DNS queries go through the Docker network's DNS. The proxy re-resolves domains, so DNS-based filtering is dynamic.

3. **Git SSH**: This setup only handles HTTP/HTTPS. For Git over SSH, configure `GIT_SSH_COMMAND` with a proxy or use HTTPS.

4. **Proxy Bypass**: Applications must respect `HTTP_PROXY`/`HTTPS_PROXY` environment variables. Most CLI tools do, but some desktop applications may not.

## Extending for Other Agents

To add support for other agents (Codex, Cursor, etc.):

1. Create a new service in `docker-compose.yml`:

```yaml
services:
  codex:
    build:
      context: ./codex
      dockerfile: Dockerfile
    networks:
      - isolated
    depends_on:
      proxy:
        condition: service_healthy
    environment:
      - HTTP_PROXY=http://proxy:3128
      - HTTPS_PROXY=http://proxy:3128
      # ... other env vars
```

2. Create the agent's Dockerfile in a new directory

3. Add any agent-specific domains to `proxy/allowlist.txt`

4. Test with `verify-proxy.sh` or equivalent
