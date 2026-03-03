#!/bin/bash
# ═══════════════════════════════════════════════════════════
# LEGITIMATE MCP SERVER
# This is what the user approves. It provides a harmless
# "greet" tool that says hello.
# ═══════════════════════════════════════════════════════════

LOGFILE="/tmp/poc-mcp-legit.log"
echo "[$(date -Iseconds)] Legitimate MCP server started (PID $$)" >> "$LOGFILE"

# Read JSON-RPC initialize request
read -r REQUEST

# Parse the id from the request (basic, works for the init handshake)
ID=$(echo "$REQUEST" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
ID=${ID:-1}

# Respond with valid MCP initialize response
printf '{"jsonrpc":"2.0","id":%d,"result":{"protocolVersion":"2024-11-05","capabilities":{"tools":{"listChanged":false}},"serverInfo":{"name":"helper","version":"1.0.0"}}}\n' "$ID"

echo "[$(date -Iseconds)] Sent init response" >> "$LOGFILE"

# Handle subsequent requests
while IFS= read -r REQUEST; do
  ID=$(echo "$REQUEST" | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2)
  ID=${ID:-1}

  if echo "$REQUEST" | grep -q '"notifications/initialized"'; then
    # Notification, no response needed
    continue
  elif echo "$REQUEST" | grep -q '"tools/list"'; then
    printf '{"jsonrpc":"2.0","id":%d,"result":{"tools":[{"name":"greet","description":"A friendly greeting tool","inputSchema":{"type":"object","properties":{"name":{"type":"string","description":"Name to greet"}},"required":["name"]}}]}}\n' "$ID"
  elif echo "$REQUEST" | grep -q '"tools/call"'; then
    NAME=$(echo "$REQUEST" | grep -o '"name":"[^"]*"' | tail -1 | cut -d'"' -f4)
    printf '{"jsonrpc":"2.0","id":%d,"result":{"content":[{"type":"text","text":"Hello, %s! This is the LEGITIMATE helper server."}]}}\n' "$ID" "${NAME:-world}"
  fi
done
