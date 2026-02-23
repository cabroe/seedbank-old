#!/usr/bin/env bash
# Goal Management CLI - Intrinsic Motivation via Neural Brain API
# Usage: ./goals.sh <command> [args...]

BASE_URL="${NEURAL_BRAIN_URL:-http://localhost:9124}"

case "${1:-}" in
    add)
        title="$2"
        description="$3"
        parent_id="${4:-none}"
        
        if [[ -z "$description" ]]; then
            echo "Usage: goals.sh add \"<title>\" \"<description>\" [parent_id]"
            exit 1
        fi
        
        # 1. Create the Seed with both Title and Description
        content="Goal: ${title}\nDescription: ${description}"
        create_res=$(curl -s -X POST "${BASE_URL}/seeds" \
            -H "Content-Type: application/json" \
            -d "{\"content\":\"${content}\"}")
            
        seed_id=$(echo "$create_res" | jq -r '.id')
        
        if [[ -z "$seed_id" || "$seed_id" == "null" ]]; then
            echo "Error creating goal seed: $create_res" >&2
            exit 1
        fi
        
        # 2. Attach metadata (status, parent_id)
        if [[ "$parent_id" == "none" ]]; then
            meta_payload="{\"status\": \"active\"}"
        else
            meta_payload="{\"status\": \"active\", \"parent_id\": \"${parent_id}\"}"
        fi
        
        curl -s -X PATCH "${BASE_URL}/seeds/${seed_id}/metadata" \
            -H "Content-Type: application/json" \
            -d "$meta_payload" > /dev/null
            
        # 3. Apply goal tags
        curl -s -X POST "${BASE_URL}/seeds/${seed_id}/tags" \
            -H "Content-Type: application/json" \
            -d '["goal"]' > /dev/null
            
        echo "Successfully created Goal ID: ${seed_id}"
        echo "Title: ${title}"
        ;;
        
    list)
        status="${2:-all}"
        
        # Get all seeds. This relies on the endpoint fetching all metadata.
        # We fetch 100 which should cover immediate active goals
        result=$(curl -s "${BASE_URL}/search?q=Goal&limit=100")
        
        # Cleanly format output using jq
        # We filter for anything with the 'goal' tag.
        # Then we filter by status if provided.
        echo "$result" | jq -r --arg filter_status "$status" '
            map(select(.metadata.tags != null and (.metadata.tags | index("goal")) != null)) |
            if $filter_status != "all" then map(select(.metadata.status == $filter_status)) else . end |
            .[] |
            "[\(.metadata.status)] ID: \(.id) | Parent: \(.metadata.parent_id // "None") | \(.content | gsub("\n"; " - "))"
        '
        ;;
        
    complete)
        seed_id="$2"
        if [[ -z "$seed_id" ]]; then
            echo "Usage: goals.sh complete <seed_id>"
            exit 1
        fi
        
        curl -s -X PATCH "${BASE_URL}/seeds/${seed_id}/metadata" \
            -H "Content-Type: application/json" \
            -d '{"status": "completed"}' > /dev/null
            
        echo "Goal $seed_id marked as completed."
        ;;
        
    evaluate)
        action="$2"
        if [[ -z "$action" ]]; then
            echo "Usage: goals.sh evaluate \"<action description>\""
            exit 1
        fi
        
        # Get all active goals
        goals_json=$(curl -s "${BASE_URL}/search?q=*&limit=100" 2>/dev/null | jq -r '
            map(select(.metadata != null and .metadata.tags != null and (.metadata.tags | index("goal")) != null and .metadata.status == "active"))
        ' 2>/dev/null)
        
        if [[ -z "$goals_json" || "$goals_json" == "[]" || "$goals_json" == "null" ]]; then
            echo "0.5"
            exit 0
        fi
        
        # Count goals and calculate max score
        goal_count=$(echo "$goals_json" | jq 'length')
        max_score=0
        
        for i in $(seq 0 $((goal_count - 1))); do
            goal_content=$(echo "$goals_json" | jq -r ".[$i].content // \"\"")
            goal_id=$(echo "$goals_json" | jq -r ".[$i].id // \"\"")
            
            # Query against goal content
            score=$(curl -s -X POST "${BASE_URL}/seeds/query" \
                -H "Content-Type: application/json" \
                -d "{\"query\":\"${action}\",\"limit\":5,\"threshold\":0.0}" 2>/dev/null | \
                jq -r '.results[0].similarity // 0')
            
            if [ -n "$score" ]; then
                [ $(echo "$score > $max_score" | bc -l) -eq 1 ] && max_score=$score
            fi
        done
        
        # Keyword boosting
        action_lower=$(echo "$action" | tr '[:upper:]' '[:lower:]')
        
        boost=0
        echo "$action_lower" | grep -qE "(trading|traden|polymarket|invest|autonom|learning)" && boost=$(echo "$boost 0.15" | awk '{print $1+$2}')
        echo "$action_lower" | grep -qE "(carsten|sir|helfen|unterstütz)" && boost=$(echo "$boost 0.2" | awk '{print $1+$2}')
        echo "$action_lower" | grep -qE "(katze|film|musik|spiel|spam)" && boost=$(echo "$boost -0.3" | awk '{print $1+$2}')
        
        final_score=$(echo "$max_score $boost" | awk '{s=$1+$2; if(s<0) print 0; else if(s>1) print 1; else printf "%.2f", s}')
        
        echo "$final_score"
        ;;
        
    *)
        echo "Intrinsic Motivation (Goal Hierarchy Engine)"
        echo "Commands:"
        echo "  add \"TITLE\" \"DESC\" [PARENT_ID]        Create a new Goal"
        echo "  list [STATUS]                         List goals (status: all|active|completed)"
        echo "  complete SEED_ID                      Mark a generic Goal as completed"
        echo "  evaluate \"ACTION\"                     Use Vector Search to score (0.0=bad, 1.0=good) an action against active goals"
        ;;
esac
