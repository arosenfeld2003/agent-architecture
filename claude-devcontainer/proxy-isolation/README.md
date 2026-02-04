# Proxy-Based Network Isolation for AI Coding Agents

This directory contains a Docker Compose setup that provides network isolation for AI coding agents using an HTTP proxy (Squid) as a controlled gateway.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Docker Environment                       │
│                                                              │
│   ┌─────────────────┐      ┌─────────────────┐              │
│   │   AI Agent      │      │   Squid Proxy   │              │
│   │ (Claude/Codex)  │─────►│   (allowlist)   │──────►Internet
│   │                 │      │                 │              │
│   └─────────────────┘      └─────────────────┘              │
│           │                        │                         │
│       [isolated]               [isolated]                    │
│       network                  + [external]                  │
│      (internal)                 networks                     │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**Key Points:**
- Agent container is on an **internal Docker network** with no direct internet access
- All HTTP/HTTPS traffic is routed through the Squid proxy via environment variables
- Proxy enforces a domain allowlist - only approved domains can be reached
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

# View proxy logs
./scripts/logs.sh --follow

# Stop the environment
./scripts/stop.sh
```

## Configuration

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

### Proxy Configuration

The Squid configuration (`proxy/squid.conf`) can be customized:

- Change cache size
- Adjust logging format
- Modify connection timeouts
- Enable SSL inspection (requires CA cert setup)

## File Structure

```
proxy-isolation/
├── docker-compose.yml      # Main compose file
├── proxy/
│   ├── Dockerfile          # Squid proxy image
│   ├── squid.conf          # Squid configuration
│   └── allowlist.txt       # Allowed domains
├── agent/
│   ├── Dockerfile          # Agent container image
│   └── verify-proxy.sh     # Network verification script
├── scripts/
│   ├── start.sh            # Start environment
│   ├── stop.sh             # Stop environment
│   ├── shell.sh            # Enter agent shell
│   └── logs.sh             # View proxy logs
└── README.md               # This file
```

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
