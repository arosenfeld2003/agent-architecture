# Enterprise CLI Agent Architecture - Mermaid Diagrams

## 1. System Overview

```mermaid
flowchart TB
    subgraph Enterprise["Enterprise Network"]
        Dev[Developer Workstation]

        subgraph Container["Sandbox Container - Docker"]
            subgraph CLI["CLI Agent"]
                Parser[Command Parser]
                Policy[Security Policy Engine]
                Executor[Tool Executor]
                Parser --> Policy --> Executor
            end

            subgraph Firewall["AI Firewall"]
                Injection[Prompt Injection Detection]
                Output[Output Filtering]
                Threat[Threat Detection & Logging]
            end

            CLI --> Firewall
        end

        Dev --> Container
    end

    subgraph Gateway["Network Gateway"]
        URL[URL Allow/Deny]
        HTTP[HTTP Method Restrictions]
    end

    Container --> Gateway

    LLM["External LLM API<br/>(Anthropic/OpenAI)<br/>'IN A BOX'"]

    Gateway --> LLM
```

## 2. Security Boundary / Trust Zones

```mermaid
flowchart LR
    subgraph Zone0["Trust Zone 0<br/>UNTRUSTED"]
        LLM[External LLM Service]
    end

    subgraph Zone1["Trust Zone 1<br/>CONTROLLED"]
        subgraph ContainerBoundary["Container Boundary"]
            AIFirewall[AI Firewall]
            NetworkProxy[Network Proxy]
        end
    end

    subgraph Zone2["Trust Zone 2<br/>TRUSTED"]
        DevWorkstation[Developer Workstation]
    end

    LLM <--> ContainerBoundary
    ContainerBoundary <--> DevWorkstation

    style Zone0 fill:#ffcccc
    style Zone1 fill:#ffffcc
    style Zone2 fill:#ccffcc
```

## 3. Data Flow - Request/Response

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant CLI as CLI Agent
    participant FW as AI Firewall
    participant GW as Network Gateway
    participant LLM as LLM API

    Dev->>CLI: 1. User Input
    CLI->>FW: 2. Policy Check
    FW-->>CLI: Action allowed?
    CLI->>FW: 3. Prompt Inspection
    Note over FW: Injection detection
    FW->>GW: 4. URL/Method Validation
    GW->>LLM: 5. API Call
    LLM-->>GW: 6. Response
    GW-->>FW: 7. Response
    Note over FW: Output sanitization
    FW-->>CLI: Filtered response
    CLI-->>Dev: 8. Execution & Display
```

## 4. Container Isolation Model

```mermaid
flowchart TB
    subgraph Host["Host Operating System"]
        subgraph Docker["Docker Runtime"]
            subgraph Container["CLI Agent Container"]
                subgraph FS["Filesystem"]
                    Ephemeral["Ephemeral FS<br/>(destroyed on exit)"]
                end

                subgraph Volumes["Mounted Volumes"]
                    Workspace["/workspace<br/>READ-WRITE<br/>Project files only"]
                    Config["/config<br/>READ-ONLY<br/>Security policies"]
                end

                subgraph Caps["Restricted Capabilities"]
                    NoPriv["no_new_priv"]
                    DropAll["drop ALL caps"]
                    Seccomp["seccomp profile"]
                end

                subgraph Resources["Resource Limits"]
                    CPU["CPU quota"]
                    Memory["Memory cap"]
                    PID["PID limit"]
                end

                subgraph NetPolicy["Network Policy"]
                    Egress["Egress: LLM API only"]
                    Ingress["Ingress: None"]
                    NoInter["No inter-container"]
                end
            end
        end

        subgraph Enforce["Enforcement Options"]
            Mandatory["Mandatory: Block if not containerized"]
            Soft["Soft-enforce: Warn but allow"]
            MDM["MDM/Policy: Endpoint management"]
        end
    end
```

## 5. Network Control Architecture

```mermaid
flowchart TB
    Container["CLI Agent Container"]

    Container --> Proxy["Egress Proxy<br/>(Mandatory)"]

    Proxy --> URLFilter
    Proxy --> HTTPFilter
    Proxy --> ContentFilter

    subgraph URLFilter["URL Filter"]
        Allow["Allowlist:<br/>api.anthropic.com<br/>api.openai.com<br/>*.company.com"]
        Deny["Denylist:<br/>*.evil.com<br/>paste.*"]
    end

    subgraph HTTPFilter["HTTP Method Filter"]
        GET["GET ✓"]
        POST["POST ?"]
        PUT["PUT ✗"]
        DELETE["DELETE ✗"]
        PostRules["POST Rules:<br/>- LLM API ✓<br/>- Webhooks ✗<br/>- Uploads ✗"]
    end

    subgraph ContentFilter["Content Filter"]
        Size["Size limits"]
        Type["Type filtering"]
        PII["PII scanning"]
        Fuzzy["Fuzzy Matching:<br/>Pattern detection<br/>Anomaly scoring"]
    end

    URLFilter --> Decision
    HTTPFilter --> Decision
    ContentFilter --> Decision

    subgraph Decision["Decision Engine"]
        direction LR
        AllowD["ALLOW<br/>+ Log"]
        DenyD["DENY<br/>+ Alert"]
        AskD["ASK<br/>+ User Confirm"]
    end
```

## 6. AI Firewall Detail

```mermaid
flowchart TB
    subgraph Inbound["INBOUND INSPECTION (to LLM)"]
        direction LR
        PI["Prompt Injection<br/>Detection<br/>• Known patterns<br/>• Jailbreak attempts<br/>• Encoding tricks"]
        CP["Context Poisoning<br/>Detection<br/>• System prompt override<br/>• Role hijacking"]
        DL["Data Leakage<br/>Check<br/>• PII detection<br/>• Secrets scanning<br/>• Credential patterns"]
    end

    subgraph Outbound["OUTBOUND INSPECTION (from LLM)"]
        direction LR
        CV["Command<br/>Validation<br/>• Dangerous commands<br/>• Scope checking<br/>• Resource limits"]
        OF["Output<br/>Filtering<br/>• Sanitize responses<br/>• Remove sensitive data"]
        HC["Harmful Content<br/>Detection<br/>• Malware patterns<br/>• Exploit code"]
    end

    Inbound --> LLM["LLM API"]
    LLM --> Outbound
```

## 7. Threat Matrix

```mermaid
flowchart LR
    subgraph Threats["THREATS"]
        T1["Prompt Injection"]
        T2["Data Exfiltration"]
        T3["Malicious Code Gen"]
        T4["Denial of Service"]
        T5["Privilege Escalation"]
        T6["Supply Chain Attack"]
    end

    subgraph Controls["CONTROLS"]
        C1["Pattern Detection"]
        C2["PII/Secret Scanning"]
        C3["Code Analysis"]
        C4["Rate Limiting"]
        C5["Capability Restrictions"]
        C6["Package Verification"]
    end

    subgraph Mitigations["MITIGATIONS"]
        M1["Block + Alert"]
        M2["Redact + Log"]
        M3["Block + Review"]
        M4["Throttle"]
        M5["Container Escape Prevention"]
        M6["Allowlist Dependencies"]
    end

    T1 --> C1 --> M1
    T2 --> C2 --> M2
    T3 --> C3 --> M3
    T4 --> C4 --> M4
    T5 --> C5 --> M5
    T6 --> C6 --> M6
```

## 8. POC vs Production Scope

```mermaid
flowchart TB
    subgraph POC["POC SCOPE - Phase 1"]
        P1["✓ Basic container isolation"]
        P2["✓ Simple URL allowlist"]
        P3["✓ Block POST except LLM API"]
        P4["✓ Basic audit logging"]
        P5["✓ File system restrictions"]
        P6["○ Soft enforcement"]
    end

    subgraph Prod["PRODUCTION - Future"]
        F1["□ AI Firewall + injection detection"]
        F2["□ PII/secrets scanning"]
        F3["□ SIEM integration"]
        F4["□ Mandatory containerization via MDM"]
        F5["□ Rate limiting + abuse detection"]
        F6["□ Code analysis"]
        F7["□ ML-based URL matching"]
    end

    POC --> |Phase 2| Prod
```

## 9. Component Interaction Overview

```mermaid
C4Context
    title CLI Agent System Context

    Person(dev, "Developer", "Uses CLI agent for coding tasks")

    System_Boundary(container, "Sandbox Container") {
        System(cli, "CLI Agent", "Executes commands and tools")
        System(firewall, "AI Firewall", "Inspects and filters traffic")
    }

    System_Ext(llm, "LLM API", "External AI service")
    System_Ext(logging, "Audit Logging", "Centralized logs")

    Rel(dev, cli, "Commands")
    Rel(cli, firewall, "Requests")
    Rel(firewall, llm, "API calls")
    Rel(container, logging, "Audit events")
```

---

## Open Questions for InfoSec

| # | Question | Options | Recommendation |
|---|----------|---------|----------------|
| 1 | Should containerization be mandatory? | Mandatory / Soft-enforce / User choice | Mandatory for production |
| 2 | POST request handling? | Block all / Allow to LLM only / Allow with approval | Allow to LLM API only |
| 3 | Where to run AI Firewall? | In container / Separate service / Cloud proxy | Separate service for auditability |
| 4 | Fuzzy URL matching approach? | Strict allowlist / ML-based / Hybrid | Start with strict allowlist |
| 5 | Logging retention? | 30 days / 90 days / 1 year | Depends on compliance requirements |
| 6 | LLM provider? | Anthropic / OpenAI / Azure / Self-hosted | TBD based on data residency |
