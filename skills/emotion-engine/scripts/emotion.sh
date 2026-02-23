#!/usr/bin/env bash
# Emotion Engine CLI - Affect Simulation via Neural Brain API
# Usage: ./emotion.sh <command> [args...]

BASE_URL="${NEURAL_BRAIN_URL:-http://localhost:9124}"

# Format JSON safely using jq (assumes jq is installed)
format_json() {
    if command -v jq &> /dev/null; then
        jq .
    else
        cat
    fi
}

clamp() {
    local val="$1"
    # bc is needed for float math
    echo "$val" | bc -l | awk '{if ($1 < 0.0) print "0.0"; else if ($1 > 10.0) print "10.0"; else printf "%.1f", $1}'
}

# Commands
case "${1:-}" in
    get)
        agent_id="$2"
        if [[ -z "$agent_id" ]]; then
            echo "Usage: emotion.sh get AGENT_ID"
            exit 1
        fi
        
        # Get the latest "working" memory context for emotions
        result=$(curl -s -X GET "${BASE_URL}/agent-contexts?agentId=${agent_id}-emotion")
        
        # Parse out the latest payload
        latest=$(echo "$result" | jq -r 'map(select(.memoryType == "working")) | sort_by(.createdAt) | last')
        
        if [[ "$latest" == "null" || -z "$latest" ]]; then
            echo '{"valence": 5.0, "arousal": 5.0, "dominance": 5.0, "reason": "baseline"}'
        else
            echo "$latest" | jq -r '.payload'
        fi
        ;;
        
    set)
        agent_id="$2"
        v="$3"
        a="$4"
        d="$5"
        reason="${6:-}"
        
        if [[ -z "$d" ]]; then
            echo "Usage: emotion.sh set AGENT_ID V A D [REASON]"
            exit 1
        fi
        
        # Force clamp between 0.0 and 10.0
        cv=$(clamp "$v")
        ca=$(clamp "$a")
        cd=$(clamp "$d")
        
        payload="{\"valence\": ${cv}, \"arousal\": ${ca}, \"dominance\": ${cd}, \"reason\": \"${reason}\"}"
        
        response=$(curl -s -X POST "${BASE_URL}/agent-contexts" \
            -H "Content-Type: application/json" \
            -d "{\"agentId\":\"${agent_id}-emotion\",\"memoryType\":\"working\",\"data\":${payload}}")
            
        # Optional: Print response for debugging if it fails
        if [[ "$response" != *"id"* ]]; then
            echo "Error saving context: $response" >&2
        fi
            
        echo "$payload"
        ;;
        
    shift)
        agent_id="$2"
        dv="$3"
        da="$4"
        dd="$5"
        reason="${6:-}"
        
        if [[ -z "$dd" ]]; then
            echo "Usage: emotion.sh shift AGENT_ID dV dA dD [REASON]"
            exit 1
        fi
        
        # Fetch current state
        current=$( "$0" get "$agent_id" )
        
        # Extract individual floats
        cv=$(echo "$current" | jq -r '.valence')
        ca=$(echo "$current" | jq -r '.arousal')
        cd=$(echo "$current" | jq -r '.dominance')
        
        # Add delta
        nv=$(echo "$cv + $dv" | bc -l)
        na=$(echo "$ca + $da" | bc -l)
        nd=$(echo "$cd + $dd" | bc -l)
        
        # Clamp and Set
        "$0" set "$agent_id" "$nv" "$na" "$nd" "$reason"
        ;;
        
    *)
        echo "Emotion Engine (V-A-D Model)"
        echo ""
        echo "Commands:"
        echo "  get AGENT_ID                       Fetch current state"
        echo "  set AGENT_ID V A D [REASON]        Set absolute state (0.0 to 10.0)"
        echo "  shift AGENT_ID dV dA dD [REASON]   Apply delta shift to state"
        ;;
esac
