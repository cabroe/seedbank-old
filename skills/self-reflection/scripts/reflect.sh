#!/usr/bin/env bash
# Meta-Cognition CLI - Self-Reflection via Seedbank API
# Usage: ./reflect.sh <command> [args...]

BASE_URL="${SEEDBANK_URL:-http://localhost:9124}"

# Format JSON safely using jq
format_json() {
    if command -v jq &> /dev/null; then
        jq .
    else
        cat
    fi
}

case "${1:-}" in
    gather)
        hours="${2:-24}"
        # We search with a generic query to get recent seeds, then we use jq to filter by date.
        # This is a bit brute-force, ideally search API natively supports time ranges.
        limit=50
        echo "Gathering short-term memory from the last $hours hours..." >&2
        
        # Calculate timestamp X hours ago
        cutoff=$(date -d "-${hours} hours" -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -v-${hours}H -u +"%Y-%m-%dT%H:%M:%SZ")
        
        result=$(curl -s "${BASE_URL}/search?q=*&limit=${limit}")
            
        # Filter and cleanly format the output for an LLM prompt
        echo "$result" | jq -r --arg cutoff "$cutoff" '
            .[] 
            | select(.created_at >= $cutoff)
            | "[\(.created_at)] (ID: \(.id)): \(.content) | Tags: \(.metadata.tags // [])"
        '
        ;;
        
    commit)
        insight="$2"
        importance="${3:-8}"
        confidence="${4:-0.8}"
        
        if [[ -z "$insight" ]]; then
            echo "Usage: reflect.sh commit \"<insight text>\" [importance] [confidence]"
            exit 1
        fi
        
        echo "Committing Deep Belief..." >&2
        
        # 1. Create the base Seed
        create_res=$(curl -s -X POST "${BASE_URL}/seeds" \
            -H "Content-Type: application/json" \
            -d "{\"content\":\"${insight}\"}")
            
        seed_id=$(echo "$create_res" | jq -r '.id')
        
        if [[ -z "$seed_id" || "$seed_id" == "null" ]]; then
            echo "Error creating seed: $create_res" >&2
            exit 1
        fi
        
        # 2. Attach metadata (importance, confidence, source)
        meta_payload="{\"importance\": ${importance}, \"confidence\": ${confidence}, \"source\": \"self_reflection\"}"
        curl -s -X PATCH "${BASE_URL}/seeds/${seed_id}/metadata" \
            -H "Content-Type: application/json" \
            -d "$meta_payload" > /dev/null
            
        # 3. Apply specific core-belief tags
        curl -s -X POST "${BASE_URL}/seeds/${seed_id}/tags" \
            -H "Content-Type: application/json" \
            -d '["reflection", "core-belief"]' > /dev/null
            
        echo "Successfully committed insight as Seed ID: ${seed_id}"
        echo "Insight: \"${insight}\""
        echo "Importance: ${importance} | Confidence: ${confidence}"
        ;;
        
    *)
        echo "Self-Reflection (Meta-Cognition Engine)"
        echo ""
        echo "Commands:"
        echo "  gather [HOURS]                                     Fetch raw short-term memory logs"
        echo "  commit \"<INSIGHT>\" [IMPORTANCE] [CONFIDENCE]       Condense an insight into a Core Belief"
        ;;
esac
