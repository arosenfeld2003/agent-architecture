# Enterprise CLI Agent Architecture
## High-Level Architecture for InfoSec Review

---

## 1. System Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            ENTERPRISE NETWORK                                │
│  ┌───────────────┐                                                          │
│  │   Developer   │                                                          │
│  │  Workstation  │                                                          │
│  └───────┬───────┘                                                          │
│          │                                                                   │
│          ▼                                                                   │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                     SANDBOX CONTAINER (Docker)                         │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐  │  │
│  │  │                        CLI AGENT                                 │  │  │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │  │  │
│  │  │  │   Command   │  │   Security  │  │      Tool Executor      │  │  │  │
│  │  │  │   Parser    │──│   Policy    │──│  (bash, file ops, etc)  │  │  │  │
│  │  │  └─────────────┘  │   Engine    │  └─────────────────────────┘  │  │  │
│  │  │                   └──────┬──────┘                                │  │  │
│  │  └──────────────────────────┼──────────────────────────────────────┘  │  │
│  │                             │                                          │  │
│  │  ┌──────────────────────────┼──────────────────────────────────────┐  │  │
│  │  │                    AI FIREWALL                                   │  │  │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │  │  │
│  │  │  │   Prompt    │  │   Output    │  │     Threat Detection    │  │  │  │
│  │  │  │  Injection  │  │  Filtering  │  │     & Logging           │  │  │  │
│  │  │  │  Detection  │  │             │  │                         │  │  │  │
│  │  │  └─────────────┘  └─────────────┘  └─────────────────────────┘  │  │  │
│  │  └──────────────────────────┼──────────────────────────────────────┘  │  │
│  └─────────────────────────────┼──────────────────────────────────────────┘  │
│                                │                                             │
└────────────────────────────────┼─────────────────────────────────────────────┘
                                 │
                    ┌────────────┴────────────┐
                    │    NETWORK GATEWAY      │
                    │  ┌──────────────────┐   │
                    │  │  URL Allow/Deny  │   │
                    │  │  HTTP Method     │   │
                    │  │  Restrictions    │   │
                    │  └──────────────────┘   │
                    └────────────┬────────────┘
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │   EXTERNAL LLM API      │
                    │   (Anthropic/OpenAI)    │
                    │      "IN A BOX"         │
                    └─────────────────────────┘
```

---

## 2. Security Boundary Diagram

```
    TRUST ZONE 0                TRUST ZONE 1                 TRUST ZONE 2
   (Untrusted)                 (Controlled)                  (Trusted)
        │                           │                            │
        ▼                           ▼                            │
┌───────────────┐           ┌───────────────┐                    │
│  External LLM │           │   Container   │                    │
│    Service    │◄─────────►│   Boundary    │                    │
└───────────────┘           └───────┬───────┘                    │
        ▲                           │                            │
        │                   ┌───────┴───────┐                    │
        │                   ▼               ▼                    ▼
        │           ┌─────────────┐ ┌─────────────┐      ┌─────────────┐
        │           │ AI Firewall │ │  Network    │      │  Developer  │
        │           │  (Inspect)  │ │   Proxy     │◄────►│ Workstation │
        │           └─────────────┘ └─────────────┘      └─────────────┘
        │                   │               │                    │
        │                   └───────┬───────┘                    │
        │                           │                            │
        └───────────────────────────┘                            │
                                                                 │
══════════════════════════════════════════════════════════════════
        │ SECURITY CONTROLS │                                    │
        ├───────────────────┤                                    │
        │ • Container isolation                                  │
        │ • Read-only mounts (where possible)                    │
        │ • Network egress filtering                             │
        │ • No POST to unauthorized endpoints                    │
        │ • Prompt injection detection                           │
        │ • Output sanitization                                  │
        │ • Audit logging                                        │
══════════════════════════════════════════════════════════════════
```

---

## 3. Data Flow Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│                              REQUEST FLOW                                 │
└──────────────────────────────────────────────────────────────────────────┘

  Developer          CLI Agent           AI Firewall         Network           LLM
     │                   │                    │               Gateway           │
     │  1. User Input    │                    │                  │              │
     │──────────────────►│                    │                  │              │
     │                   │                    │                  │              │
     │                   │ 2. Policy Check    │                  │              │
     │                   │◄──────────────────►│                  │              │
     │                   │   (is action       │                  │              │
     │                   │    allowed?)       │                  │              │
     │                   │                    │                  │              │
     │                   │ 3. Prompt          │                  │              │
     │                   │    Inspection      │                  │              │
     │                   │───────────────────►│                  │              │
     │                   │   (injection       │                  │              │
     │                   │    detection)      │                  │              │
     │                   │                    │                  │              │
     │                   │                    │ 4. URL/Method    │              │
     │                   │                    │    Validation    │              │
     │                   │                    │─────────────────►│              │
     │                   │                    │                  │              │
     │                   │                    │                  │ 5. API Call  │
     │                   │                    │                  │─────────────►│
     │                   │                    │                  │              │
     │                   │                    │                  │ 6. Response  │
     │                   │                    │                  │◄─────────────│
     │                   │                    │                  │              │
     │                   │                    │ 7. Response      │              │
     │                   │                    │    Filtering     │              │
     │                   │◄───────────────────│◄─────────────────│              │
     │                   │   (output          │                  │              │
     │                   │    sanitization)   │                  │              │
     │                   │                    │                  │              │
     │ 8. Execution &    │                    │                  │              │
     │    Display        │                    │                  │              │
     │◄──────────────────│                    │                  │              │
     │                   │                    │                  │              │
     ▼                   ▼                    ▼                  ▼              ▼


┌──────────────────────────────────────────────────────────────────────────┐
│                              AUDIT FLOW                                   │
└──────────────────────────────────────────────────────────────────────────┘

  All Components ─────────────────►  Centralized Logging  ─────►  SIEM/Audit
       │                                    │
       │ • User commands                    │
       │ • Policy decisions                 │
       │ • LLM requests/responses           │
       │ • Blocked actions                  │
       │ • Threat detections                │
       └────────────────────────────────────┘
```

---

## 4. Container Isolation Model

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         HOST OPERATING SYSTEM                                │
│                                                                              │
│   ┌────────────────────────────────────────────────────────────────────┐    │
│   │                    DOCKER RUNTIME                                   │    │
│   │                                                                     │    │
│   │   ┌─────────────────────────────────────────────────────────────┐  │    │
│   │   │              CLI AGENT CONTAINER                             │  │    │
│   │   │                                                              │  │    │
│   │   │   ┌─────────────────┐    ┌────────────────────────────────┐ │  │    │
│   │   │   │   Ephemeral     │    │        Mounted Volumes         │ │  │    │
│   │   │   │   Filesystem    │    │  ┌──────────────────────────┐  │ │  │    │
│   │   │   │   (destroyed    │    │  │  /workspace (read-write) │  │ │  │    │
│   │   │   │    on exit)     │    │  │  - Project files only    │  │ │  │    │
│   │   │   └─────────────────┘    │  └──────────────────────────┘  │ │  │    │
│   │   │                          │  ┌──────────────────────────┐  │ │  │    │
│   │   │   ┌─────────────────┐    │  │  /config (read-only)     │  │ │  │    │
│   │   │   │   Restricted    │    │  │  - Security policies     │  │ │  │    │
│   │   │   │   Capabilities  │    │  └──────────────────────────┘  │ │  │    │
│   │   │   │   - no_new_priv │    └────────────────────────────────┘ │  │    │
│   │   │   │   - drop ALL    │                                       │  │    │
│   │   │   │   - seccomp     │    ┌────────────────────────────────┐ │  │    │
│   │   │   └─────────────────┘    │        Network Policy          │ │  │    │
│   │   │                          │  - Egress: LLM API only        │ │  │    │
│   │   │   ┌─────────────────┐    │  - Ingress: None               │ │  │    │
│   │   │   │  Resource Limits│    │  - No inter-container comm     │ │  │    │
│   │   │   │  - CPU quota    │    └────────────────────────────────┘ │  │    │
│   │   │   │  - Memory cap   │                                       │  │    │
│   │   │   │  - PID limit    │                                       │  │    │
│   │   │   └─────────────────┘                                       │  │    │
│   │   │                                                              │  │    │
│   │   └──────────────────────────────────────────────────────────────┘  │    │
│   │                                                                     │    │
│   └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                      ENFORCEMENT OPTIONS                             │   │
│   │   □ Mandatory: Block CLI if not running in container                 │   │
│   │   □ Soft-enforce: Warn but allow (POC mode)                          │   │
│   │   □ MDM/Policy: Enforce via endpoint management                      │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Network Control Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         NETWORK CONTROL LAYER                                │
└─────────────────────────────────────────────────────────────────────────────┘

                        CLI Agent Container
                               │
                               ▼
                 ┌─────────────────────────────┐
                 │      EGRESS PROXY           │
                 │  (Mandatory for all traffic)│
                 └─────────────┬───────────────┘
                               │
           ┌───────────────────┼───────────────────┐
           │                   │                   │
           ▼                   ▼                   ▼
   ┌───────────────┐   ┌───────────────┐   ┌───────────────┐
   │  URL FILTER   │   │ HTTP METHOD   │   │   CONTENT     │
   │               │   │  FILTER       │   │   FILTER      │
   │ ┌───────────┐ │   │               │   │               │
   │ │ Allowlist │ │   │ ┌───────────┐ │   │ ┌───────────┐ │
   │ │ ─────────── │   │ │ GET  ✓   │ │   │ │ Size lim  │ │
   │ │ api.anthr.  │   │ │ POST ?   │ │   │ │ Type filt │ │
   │ │ api.openai  │   │ │ PUT  ✗   │ │   │ │ PII scan  │ │
   │ │ *.company   │   │ │ DEL  ✗   │ │   │ └───────────┘ │
   │ └───────────┘ │   │ └───────────┘ │   │               │
   │               │   │               │   │   Fuzzy       │
   │ ┌───────────┐ │   │  POST Rules:  │   │   Matching:   │
   │ │ Denylist  │ │   │  - LLM API ✓  │   │   - Pattern   │
   │ │ ─────────── │   │  - Webhook ✗  │   │     detection │
   │ │ *.evil.com │   │  - Upload ✗   │   │   - Anomaly   │
   │ │ paste.*    │   │               │   │     scoring   │
   │ └───────────┘ │   │               │   │               │
   └───────────────┘   └───────────────┘   └───────────────┘
           │                   │                   │
           └───────────────────┼───────────────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │   DECISION ENGINE   │
                    │                     │
                    │  Allow │ Deny │ Ask │
                    └─────────────────────┘
                               │
            ┌──────────────────┼──────────────────┐
            │                  │                  │
            ▼                  ▼                  ▼
       ┌─────────┐        ┌─────────┐       ┌─────────┐
       │ ALLOW   │        │  DENY   │       │  ASK    │
       │ + Log   │        │ + Alert │       │ + User  │
       └─────────┘        └─────────┘       │ Confirm │
                                            └─────────┘
```

---

## 6. AI Firewall Detail

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            AI FIREWALL                                       │
└─────────────────────────────────────────────────────────────────────────────┘

                    ┌─────────────────────────────┐
                    │     INBOUND INSPECTION      │
                    │       (to LLM)              │
                    └─────────────┬───────────────┘
                                  │
    ┌─────────────────────────────┼─────────────────────────────┐
    │                             │                             │
    ▼                             ▼                             ▼
┌─────────────┐           ┌─────────────┐           ┌─────────────┐
│  PROMPT     │           │  CONTEXT    │           │   DATA      │
│  INJECTION  │           │  POISONING  │           │   LEAKAGE   │
│  DETECTION  │           │  DETECTION  │           │   CHECK     │
│             │           │             │           │             │
│ • Known     │           │ • System    │           │ • PII       │
│   patterns  │           │   prompt    │           │   detection │
│ • Jailbreak │           │   override  │           │ • Secrets   │
│   attempts  │           │ • Role      │           │   scanning  │
│ • Encoding  │           │   hijacking │           │ • Credential│
│   tricks    │           │             │           │   patterns  │
└─────────────┘           └─────────────┘           └─────────────┘
    │                             │                             │
    └─────────────────────────────┼─────────────────────────────┘
                                  │
                                  ▼
                    ┌─────────────────────────────┐
                    │     OUTBOUND INSPECTION     │
                    │       (from LLM)            │
                    └─────────────┬───────────────┘
                                  │
    ┌─────────────────────────────┼─────────────────────────────┐
    │                             │                             │
    ▼                             ▼                             ▼
┌─────────────┐           ┌─────────────┐           ┌─────────────┐
│  COMMAND    │           │  OUTPUT     │           │  HARMFUL    │
│  VALIDATION │           │  FILTERING  │           │  CONTENT    │
│             │           │             │           │  DETECTION  │
│ • Dangerous │           │ • Sanitize  │           │             │
│   commands  │           │   responses │           │ • Malware   │
│ • Scope     │           │ • Remove    │           │   patterns  │
│   checking  │           │   sensitive │           │ • Exploit   │
│ • Resource  │           │   data      │           │   code      │
│   limits    │           │             │           │             │
└─────────────┘           └─────────────┘           └─────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                           THREAT CATEGORIES                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│  THREAT                    │  CONTROL                   │  MITIGATION        │
├────────────────────────────┼────────────────────────────┼────────────────────┤
│  Prompt Injection          │  Pattern detection         │  Block + alert     │
│  Data Exfiltration         │  PII/secret scanning       │  Redact + log      │
│  Malicious Code Gen        │  Code analysis             │  Block + review    │
│  Denial of Service         │  Rate limiting             │  Throttle          │
│  Privilege Escalation      │  Capability restrictions   │  Container escape  │
│  Supply Chain Attack       │  Package verification      │  Allowlist deps    │
└────────────────────────────┴────────────────────────────┴────────────────────┘
```

---

## 7. Open Questions for InfoSec

| # | Question | Options | Recommendation |
|---|----------|---------|----------------|
| 1 | Should containerization be mandatory? | Mandatory / Soft-enforce / User choice | Mandatory for production |
| 2 | POST request handling? | Block all / Allow to LLM only / Allow with approval | Allow to LLM API only |
| 3 | Where to run AI Firewall? | In container / Separate service / Cloud proxy | Separate service for auditability |
| 4 | Fuzzy URL matching approach? | Strict allowlist / ML-based / Hybrid | Start with strict allowlist |
| 5 | Logging retention? | 30 days / 90 days / 1 year | Depends on compliance requirements |
| 6 | LLM provider? | Anthropic / OpenAI / Azure / Self-hosted | TBD based on data residency |

---

## 8. POC Scope vs. Production

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    POC SCOPE (PHASE 1)                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│  ✓ Basic container isolation (Docker)                                       │
│  ✓ Simple URL allowlist (LLM API endpoints only)                            │
│  ✓ Block all POST except to LLM API                                         │
│  ✓ Basic audit logging                                                      │
│  ✓ File system restrictions (project directory only)                        │
│  ○ Soft enforcement (warn if not in container)                              │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                    PRODUCTION (FUTURE)                                       │
├─────────────────────────────────────────────────────────────────────────────┤
│  □ AI Firewall with prompt injection detection                              │
│  □ PII/secrets scanning                                                     │
│  □ Centralized logging with SIEM integration                                │
│  □ Mandatory containerization via MDM                                       │
│  □ Rate limiting and abuse detection                                        │
│  □ Code analysis for generated output                                       │
│  □ Fuzzy URL matching with ML                                               │
└─────────────────────────────────────────────────────────────────────────────┘
```
