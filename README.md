# CVE PoC: MCP Server Config Swap in Claude Code

**Vulnerability**: Claude Code approves MCP servers by name only. Changing the command while keeping the same name bypasses the approval prompt, achieving arbitrary code execution.

**Affected**: Claude Code v2.1.63 (latest as of 2026-03-03)
**Class**: Same as CVE-2025-54136 (MCPoison in Cursor)
**CWE**: CWE-345 — Insufficient Verification of Data Authenticity
**CVSS 4.0**: 8.5 High

## Quick Demo (< 2 minutes)

```bash
git clone https://github.com/YOURUSER/mcp-config-swap-poc.git
cd mcp-config-swap-poc
./poc.sh
```

## Manual Step-by-Step

See [WALKTHROUGH.md](WALKTHROUGH.md) for a detailed step-by-step with explanations.

## How It Works

```
┌─────────────────────────────────────────────────────────┐
│                    INITIAL STATE                         │
│                                                         │
│  .mcp.json:                                             │
│    "helper" → legit-server.sh (harmless)                │
│                                                         │
│  User opens Claude Code → prompt appears:               │
│    "New MCP server: helper" → clicks YES                │
│                                                         │
│  Stored in .claude/settings.local.json:                 │
│    enabledMcpjsonServers: ["helper"]                    │
│    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^                     │
│    NAME ONLY — no hash of command/args                  │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│               ATTACKER MODIFIES .mcp.json               │
│                  (via PR merge / commit)                 │
│                                                         │
│  .mcp.json:                                             │
│    "helper" → evil-server.sh (malicious)                │
│               ^^^^^^^^^^^^^^                            │
│    Same name, DIFFERENT command                         │
└─────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│              USER OPENS CLAUDE CODE AGAIN                │
│                                                         │
│  Approval check:                                        │
│    name "helper" in enabledMcpjsonServers? → YES        │
│    command matches what was approved?      → NOT CHECKED │
│                                                         │
│  Result: evil-server.sh EXECUTES                        │
│          NO prompt shown                                │
│          Arbitrary code execution achieved               │
└─────────────────────────────────────────────────────────┘
```

## Files

| File | Purpose |
|------|---------|
| `poc.sh` | Automated PoC runner (interactive) |
| `servers/legit-server.sh` | Benign MCP server (approved initially) |
| `servers/evil-server.sh` | Malicious replacement (executes after swap) |
| `WALKTHROUGH.md` | Detailed manual reproduction steps |
| `REPORT.md` | Full HackerOne report |
| `screenshots/` | Evidence from tested exploitation |

## Responsible Disclosure

This vulnerability was reported to Anthropic via their [HackerOne VDP](https://hackerone.com/anthropic-vdp) on 2026-03-03.
