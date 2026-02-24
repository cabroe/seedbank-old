#!/usr/bin/env bash
# Neural Brain Agent Memory CLI — Neutron-compatible interface
# Use NEURAL_BRAIN_URL to point at Neural Brain (default http://localhost:9124).

BASE_URL="${NEURAL_BRAIN_URL:-}"
CONFIG_FILE="${HOME}/.config/neural-brain/credentials.json"

# Load credentials - env vars first, then credentials file
APP_ID="${NEURAL_BRAIN_AGENT_ID:-}"
EXTERNAL_USER_ID="${NEURAL_BRAIN_EXTERNAL_USER_ID:-}"

if [[ -z "$BASE_URL" ]] || [[ -z "$APP_ID" ]]; then
    if [[ -f "$CONFIG_FILE" ]]; then
        if command -v jq &> /dev/null; then
            [[ -z "$BASE_URL" ]] && BASE_URL=$(jq -r '.url // empty' "$CONFIG_FILE" 2>/dev/null)
            [[ -z "$APP_ID" ]] && APP_ID=$(jq -r '.agent_id // empty' "$CONFIG_FILE" 2>/dev/null)
            [[ -z "$EXTERNAL_USER_ID" ]] && EXTERNAL_USER_ID=$(jq -r '.external_user_id // empty' "$CONFIG_FILE" 2>/dev/null)
        else
            [[ -z "$BASE_URL" ]] && BASE_URL=$(grep '"url"' "$CONFIG_FILE" | sed 's/.*"url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
            [[ -z "$APP_ID" ]] && APP_ID=$(grep '"agent_id"' "$CONFIG_FILE" | sed 's/.*"agent_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
            [[ -z "$EXTERNAL_USER_ID" ]] && EXTERNAL_USER_ID=$(grep '"external_user_id"' "$CONFIG_FILE" | sed 's/.*"external_user_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
        fi
    fi
fi

# Fallback defaults
BASE_URL="${BASE_URL:-http://localhost:9124}"
EXTERNAL_USER_ID="${EXTERNAL_USER_ID:-1}"

# Optional query params for multi-tenancy
QUERY_PARAMS=""
if [[ -n "$APP_ID" ]]; then
    QUERY_PARAMS="appId=${APP_ID}&externalUserId=${EXTERNAL_USER_ID}"
fi

# Pretty-print JSON if jq is available
format_json() {
    if command -v jq &> /dev/null; then
        local input
        input=$(cat)
        if [[ -z "$input" ]]; then return; fi
        if printf "%s" "$input" | jq . >/dev/null 2>&1; then
            printf "%s" "$input" | jq .
        else
            printf "%s\n" "$input"
        fi
    else
        cat
    fi
}

# Commands
case "${1:-}" in
    save)
        text="$2"
        title="${3:-Untitled}"
        if [[ -z "$text" ]]; then
            echo "Usage: neural-brain-memory save TEXT [TITLE]"
            exit 1
        fi
        if [[ -n "$QUERY_PARAMS" ]]; then
            curl -s -X POST "${BASE_URL}/seeds?${QUERY_PARAMS}" \
                -F "text=[\"${text}\"]" \
                -F 'textTypes=["text"]' \
                -F 'textSources=["bot_save"]' \
                -F "textTitles=[\"${title}\"]" | format_json
        else
            curl -s -X POST "${BASE_URL}/seeds" \
                -F "text=[\"${text}\"]" \
                -F 'textTypes=["text"]' \
                -F 'textSources=["bot_save"]' \
                -F "textTitles=[\"${title}\"]" | format_json
        fi
        ;;
    search)
        query="$2"
        limit="${3:-10}"
        threshold="${4:-0.5}"
        seed_ids="${5:-}"
        if [[ -z "$query" ]]; then
            echo "Usage: neural-brain-memory search QUERY [LIMIT] [THRESHOLD] [SEED_IDS]"
            echo "Example: neural-brain-memory search \"hello\" 10 0.5 \"1,2,3\""
            exit 1
        fi
        
        # Build JSON body
        if [[ -n "$seed_ids" ]]; then
            # Convert comma-separated string to JSON array
            json_ids=$(echo "$seed_ids" | jq -R 'split(",") | map(tonumber)' 2>/dev/null || echo "[]")
            payload="{\"query\":\"${query}\",\"limit\":${limit},\"threshold\":${threshold},\"seedIds\":${json_ids}}"
        else
            payload="{\"query\":\"${query}\",\"limit\":${limit},\"threshold\":${threshold}}"
        fi

        if [[ -n "$QUERY_PARAMS" ]]; then
            curl -s -X POST "${BASE_URL}/seeds/query?${QUERY_PARAMS}" \
                -H "Content-Type: application/json" \
                -d "$payload" | format_json
        else
            curl -s -X POST "${BASE_URL}/seeds/query" \
                -H "Content-Type: application/json" \
                -d "$payload" | format_json
        fi
        ;;
    context-create)
        agent_id="$2"
        memory_type="$3"
        data="$4"
        metadata="${5:-{}}"
        if [[ -z "$agent_id" || -z "$memory_type" || -z "$data" ]]; then
            echo "Usage: neural-brain-memory context-create AGENT_ID MEMORY_TYPE JSON_DATA [JSON_METADATA]"
            echo ""
            echo "Memory types: episodic, semantic, procedural, working"
            exit 1
        fi
        if [[ -n "$QUERY_PARAMS" ]]; then
            curl -s -X POST "${BASE_URL}/agent-contexts?${QUERY_PARAMS}" \
                -H "Content-Type: application/json" \
                -d "{\"agentId\":\"${agent_id}\",\"memoryType\":\"${memory_type}\",\"data\":${data},\"metadata\":${metadata}}" | format_json
        else
            curl -s -X POST "${BASE_URL}/agent-contexts" \
                -H "Content-Type: application/json" \
                -d "{\"agentId\":\"${agent_id}\",\"memoryType\":\"${memory_type}\",\"data\":${data},\"metadata\":${metadata}}" | format_json
        fi
        ;;
    context-list)
        agent_id="$2"
        extra=""
        if [[ -n "$agent_id" ]]; then
            extra="&agentId=${agent_id}"
        fi
        if [[ -n "$QUERY_PARAMS" ]]; then
            curl -s -X GET "${BASE_URL}/agent-contexts?${QUERY_PARAMS}${extra}" | format_json
        else
            curl -s -X GET "${BASE_URL}/agent-contexts?${extra}" | format_json
        fi
        ;;
    context-get)
        context_id="$2"
        if [[ -z "$context_id" ]]; then
            echo "Usage: neural-brain-memory context-get CONTEXT_ID"
            exit 1
        fi
        if [[ -n "$QUERY_PARAMS" ]]; then
            curl -s -X GET "${BASE_URL}/agent-contexts/${context_id}?${QUERY_PARAMS}" | format_json
        else
            curl -s -X GET "${BASE_URL}/agent-contexts/${context_id}" | format_json
        fi
        ;;
    test)
        echo "Testing Neural Brain API connection..."
        if [[ -n "$QUERY_PARAMS" ]]; then
            result=$(curl -s -X POST "${BASE_URL}/seeds/query?${QUERY_PARAMS}" \
                -H "Content-Type: application/json" \
                -d '{"query":"test","limit":1}')
        else
            result=$(curl -s -X POST "${BASE_URL}/seeds/query" \
                -H "Content-Type: application/json" \
                -d '{"query":"test","limit":1}')
        fi
        if [[ $? -eq 0 && "$result" != *"error"* && "$result" != *"Unauthorized"* ]]; then
            echo "API connection successful"
            echo "$result" | format_json
        else
            echo "API connection failed"
            echo "$result" | format_json
            exit 1
        fi
        ;;
    *)
        echo "Neural Brain Agent Memory CLI"
        echo ""
        echo "Usage: neural-brain-memory [command] [args]"
        echo ""
        echo "Seed Commands:"
        echo "  save TEXT [TITLE]                                 Save text as a seed"
        echo "  search QUERY [LIMIT] [THRESHOLD] [SEED_IDS]       Semantic search (optional seedIds filter)"
        echo ""
        echo "Agent Context Commands:"
        echo "  context-create AGENT_ID TYPE JSON_DATA [JSON_METADATA]"
        echo "                                            Create agent context"
        echo "  context-list [AGENT_ID]                   List agent contexts"
        echo "  context-get CONTEXT_ID                    Get specific context"
        echo ""
        echo "Utility:"
        echo "  test                                      Test API connection"
        echo ""
        echo "Environment: NEURAL_BRAIN_URL, NEURAL_BRAIN_AGENT_ID, NEURAL_BRAIN_EXTERNAL_USER_ID"
        echo ""
        echo "Examples:"
        echo "  neural-brain-memory save \"Hello world\" \"My first seed\""
        echo "  neural-brain-memory search \"hello\" 10 0.5"
        echo "  neural-brain-memory context-create \"my-agent\" \"episodic\" '{\"key\":\"value\"}'"
        echo "  neural-brain-memory context-list \"my-agent\""
        echo "  neural-brain-memory context-get abc-123"
        ;;
esac
