#!/usr/bin/env bash
# Auto-Recall: Query memories before AI turn (Neutron-compatible: POST /seeds/query, .results[].content)

# Check if auto-recall is enabled (default: true) — support both env names for compatibility
VANAR_AUTO_RECALL="${VANAR_AUTO_RECALL:-${NEURAL_BRAIN_AUTO_RECALL:-true}}"
[[ "$VANAR_AUTO_RECALL" != "true" ]] && exit 0

set -euo pipefail

BASE_URL="${NEURAL_BRAIN_URL:-http://localhost:9124}"
APP_ID="${NEUTRON_AGENT_ID:-}"
EXTERNAL_USER_ID="${YOUR_AGENT_IDENTIFIER:-1}"

QUERY_PARAMS=""
[[ -n "$APP_ID" ]] && QUERY_PARAMS="appId=${APP_ID}&externalUserId=${EXTERNAL_USER_ID}"

USER_MESSAGE="${OPENCLAW_USER_MESSAGE:-}"
[[ -z "$USER_MESSAGE" ]] && exit 0

# Neutron-compatible: POST /seeds/query with JSON body; response has .results[].content
if [[ -n "$QUERY_PARAMS" ]]; then
    response=$(curl -s -X POST "${BASE_URL}/seeds/query?${QUERY_PARAMS}" \
        -H "Content-Type: application/json" \
        -d "{\"query\":\"${USER_MESSAGE}\",\"limit\":5,\"threshold\":0.5}" 2>/dev/null || echo "{\"results\":[]}")
else
    response=$(curl -s -X POST "${BASE_URL}/seeds/query" \
        -H "Content-Type: application/json" \
        -d "{\"query\":\"${USER_MESSAGE}\",\"limit\":5,\"threshold\":0.5}" 2>/dev/null || echo "{\"results\":[]}")
fi

memories=$(echo "$response" | jq -r '.results[]?.content // empty' 2>/dev/null | head -500)

if [[ -n "$memories" ]]; then
    echo "---"
    echo "RECALLED MEMORIES:"
    echo "$memories"
    echo "---"
fi
