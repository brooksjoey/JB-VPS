#!/usr/bin/env bash
# AI Assistant Plugin for JB-VPS
# Provides persistent memory, knowledge base, and intelligent automation

set -euo pipefail
source "$JB_DIR/lib/base.sh"

# AI plugin configuration
declare -g AI_DIR="$JB_DIR/plugins/ai"
declare -g AI_MEMORY_DIR="$AI_DIR/memory"
declare -g AI_KNOWLEDGE_DIR="$AI_DIR/knowledge"
declare -g AI_SESSIONS_DIR="$AI_DIR/sessions"
declare -g AI_CONFIG_FILE="$AI_DIR/config.json"
declare -g AI_MEMORY_DB="$AI_MEMORY_DIR/persistent_memory.json"
declare -g AI_KNOWLEDGE_DB="$AI_KNOWLEDGE_DIR/knowledge_base.json"
declare -g AI_CURRENT_SESSION="$AI_SESSIONS_DIR/current_session.json"

# Initialize AI plugin
ai_init() {
    log_info "Initializing AI Assistant with persistent memory" "AI"
    
    # Create directory structure
    mkdir -p "$AI_MEMORY_DIR" "$AI_KNOWLEDGE_DIR" "$AI_SESSIONS_DIR"
    
    # Initialize configuration
    if [[ ! -f "$AI_CONFIG_FILE" ]]; then
        ai_create_default_config
    fi
    
    # Initialize memory database
    if [[ ! -f "$AI_MEMORY_DB" ]]; then
        ai_create_memory_db
    fi
    
    # Initialize knowledge base
    if [[ ! -f "$AI_KNOWLEDGE_DB" ]]; then
        ai_create_knowledge_db
    fi
    
    # Start new session
    ai_start_session
    
    log_debug "AI Assistant initialized" "AI"
}

# Create default configuration
ai_create_default_config() {
    cat > "$AI_CONFIG_FILE" << 'EOF'
{
    "version": "1.0.0",
    "memory": {
        "max_entries": 10000,
        "retention_days": 365,
        "auto_cleanup": true,
        "compression": true
    },
    "knowledge": {
        "categories": [
            "system_administration",
            "security",
            "networking",
            "development",
            "troubleshooting",
            "automation",
            "red_team",
            "general"
        ],
        "auto_categorize": true,
        "similarity_threshold": 0.8
    },
    "sessions": {
        "max_sessions": 100,
        "auto_save": true,
        "session_timeout": 3600
    },
    "features": {
        "learning_mode": true,
        "context_awareness": true,
        "predictive_suggestions": true,
        "auto_documentation": true
    }
}
EOF
    log_info "Created default AI configuration" "AI"
}

# Create memory database
ai_create_memory_db() {
    cat > "$AI_MEMORY_DB" << 'EOF'
{
    "metadata": {
        "version": "1.0.0",
        "created": "",
        "last_updated": "",
        "total_entries": 0,
        "categories": {}
    },
    "memories": [],
    "relationships": [],
    "patterns": []
}
EOF
    
    # Update metadata
    local timestamp=$(date -Iseconds)
    jq --arg ts "$timestamp" '.metadata.created = $ts | .metadata.last_updated = $ts' "$AI_MEMORY_DB" > "${AI_MEMORY_DB}.tmp" && mv "${AI_MEMORY_DB}.tmp" "$AI_MEMORY_DB"
    
    log_info "Created AI memory database" "AI"
}

# Create knowledge base
ai_create_knowledge_db() {
    cat > "$AI_KNOWLEDGE_DB" << 'EOF'
{
    "metadata": {
        "version": "1.0.0",
        "created": "",
        "last_updated": "",
        "total_articles": 0,
        "categories": {}
    },
    "articles": [],
    "tags": [],
    "references": []
}
EOF
    
    # Update metadata and add initial knowledge
    local timestamp=$(date -Iseconds)
    jq --arg ts "$timestamp" '.metadata.created = $ts | .metadata.last_updated = $ts' "$AI_KNOWLEDGE_DB" > "${AI_KNOWLEDGE_DB}.tmp" && mv "${AI_KNOWLEDGE_DB}.tmp" "$AI_KNOWLEDGE_DB"
    
    # Add initial VPS knowledge
    ai_add_initial_knowledge
    
    log_info "Created AI knowledge base" "AI"
}

# Add initial VPS knowledge
ai_add_initial_knowledge() {
    local articles=(
        '{"id":"vps-basics","title":"VPS Management Basics","category":"system_administration","content":"A VPS (Virtual Private Server) is a virtualized server that provides dedicated resources within a shared physical server. Key management tasks include system updates, security hardening, monitoring, and backup management.","tags":["vps","basics","administration"],"created":"'$(date -Iseconds)'","importance":9}'
        '{"id":"security-hardening","title":"Security Hardening Best Practices","category":"security","content":"Essential security measures include: disabling root login, using SSH keys, configuring fail2ban, setting up UFW firewall, regular updates, and monitoring system logs.","tags":["security","hardening","best-practices"],"created":"'$(date -Iseconds)'","importance":10}'
        '{"id":"ssh-management","title":"SSH Key Management","category":"security","content":"SSH keys provide secure authentication. Generate with ssh-keygen, copy with ssh-copy-id, and manage authorized_keys file. Disable password authentication after key setup.","tags":["ssh","keys","authentication"],"created":"'$(date -Iseconds)'","importance":8}'
        '{"id":"monitoring-basics","title":"System Monitoring Fundamentals","category":"system_administration","content":"Monitor CPU, memory, disk usage, and network. Use tools like htop, iotop, netstat. Set up alerts for critical thresholds. Log analysis is crucial for troubleshooting.","tags":["monitoring","performance","troubleshooting"],"created":"'$(date -Iseconds)'","importance":7}'
    )
    
    for article in "${articles[@]}"; do
        jq --argjson article "$article" '.articles += [$article] | .metadata.total_articles += 1' "$AI_KNOWLEDGE_DB" > "${AI_KNOWLEDGE_DB}.tmp" && mv "${AI_KNOWLEDGE_DB}.tmp" "$AI_KNOWLEDGE_DB"
    done
    
    log_info "Added initial knowledge articles" "AI"
}

# Start new session
ai_start_session() {
    local session_id="session_$(date +%s)_$$"
    local timestamp=$(date -Iseconds)
    
    cat > "$AI_CURRENT_SESSION" << EOF
{
    "session_id": "$session_id",
    "started": "$timestamp",
    "user": "${SUDO_USER:-$USER}",
    "hostname": "$(hostname)",
    "context": {
        "vps_state": "$(jb_state_get "bootstrap_completed" || echo "unknown")",
        "last_maintenance": "$(jb_state_get "last_maintenance" || echo "never")",
        "security_level": "$(jb_state_get "security_hardened" || echo "unknown")"
    },
    "interactions": [],
    "learned_facts": [],
    "suggestions": []
}
EOF
    
    log_info "Started AI session: $session_id" "AI"
}

# Memory management functions
ai_memory() {
    local action="${1:-show}"
    
    case "$action" in
        "show"|"list")
            ai_memory_show
            ;;
        "add")
            shift
            ai_memory_add "$@"
            ;;
        "search")
            shift
            ai_memory_search "$@"
            ;;
        "stats")
            ai_memory_stats
            ;;
        "cleanup")
            ai_memory_cleanup
            ;;
        *)
            ai_memory_help
            ;;
    esac
}

# Show memory contents
ai_memory_show() {
    echo "🧠 AI Persistent Memory"
    echo "======================="
    echo ""
    
    if [[ ! -f "$AI_MEMORY_DB" ]]; then
        echo "Memory database not found. Run 'jb ai:init' first."
        return 1
    fi
    
    local total_entries
    total_entries=$(jq -r '.metadata.total_entries' "$AI_MEMORY_DB")
    
    echo "Total memories: $total_entries"
    echo "Last updated: $(jq -r '.metadata.last_updated' "$AI_MEMORY_DB")"
    echo ""
    
    if [[ $total_entries -gt 0 ]]; then
        echo "Recent memories:"
        jq -r '.memories[-10:] | .[] | "[\(.timestamp)] \(.category): \(.content[0:100])..."' "$AI_MEMORY_DB"
    else
        echo "No memories stored yet."
    fi
}

# Add memory entry
ai_memory_add() {
    local category="$1"
    local content="$2"
    local importance="${3:-5}"
    
    if [[ -z "$category" ]] || [[ -z "$content" ]]; then
        echo "Usage: jb ai:memory add <category> <content> [importance]"
        return 1
    fi
    
    local memory_entry
    memory_entry=$(jq -n \
        --arg id "mem_$(date +%s)_$(shuf -i 1000-9999 -n 1)" \
        --arg category "$category" \
        --arg content "$content" \
        --arg timestamp "$(date -Iseconds)" \
        --argjson importance "$importance" \
        --arg session "$(jq -r '.session_id' "$AI_CURRENT_SESSION" 2>/dev/null || echo "unknown")" \
        '{
            id: $id,
            category: $category,
            content: $content,
            timestamp: $timestamp,
            importance: $importance,
            session: $session,
            tags: [],
            relationships: []
        }')
    
    # Add to memory database
    jq --argjson entry "$memory_entry" \
        '.memories += [$entry] | 
         .metadata.total_entries += 1 | 
         .metadata.last_updated = now | strftime("%Y-%m-%dT%H:%M:%S%z")' \
        "$AI_MEMORY_DB" > "${AI_MEMORY_DB}.tmp" && mv "${AI_MEMORY_DB}.tmp" "$AI_MEMORY_DB"
    
    echo "✅ Memory added: $category"
    log_info "Added AI memory: $category" "AI"
}

# Search memory
ai_memory_search() {
    local query="$1"
    
    if [[ -z "$query" ]]; then
        echo "Usage: jb ai:memory search <query>"
        return 1
    fi
    
    echo "🔍 Searching AI memory for: $query"
    echo "=================================="
    echo ""
    
    jq -r --arg query "$query" \
        '.memories[] | select(.content | test($query; "i")) | 
         "[\(.timestamp)] \(.category): \(.content)"' \
        "$AI_MEMORY_DB"
}

# Memory statistics
ai_memory_stats() {
    echo "📊 AI Memory Statistics"
    echo "======================"
    echo ""
    
    local total_entries
    total_entries=$(jq -r '.metadata.total_entries' "$AI_MEMORY_DB")
    
    echo "Total entries: $total_entries"
    echo "Database size: $(du -h "$AI_MEMORY_DB" | cut -f1)"
    echo "Created: $(jq -r '.metadata.created' "$AI_MEMORY_DB")"
    echo "Last updated: $(jq -r '.metadata.last_updated' "$AI_MEMORY_DB")"
    echo ""
    
    echo "Categories:"
    jq -r '.memories | group_by(.category) | .[] | "\(.[0].category): \(length) entries"' "$AI_MEMORY_DB" | sort
    echo ""
    
    echo "Importance distribution:"
    jq -r '.memories | group_by(.importance) | .[] | "Level \(.[0].importance): \(length) entries"' "$AI_MEMORY_DB" | sort
}

# Knowledge base functions
ai_knowledge() {
    local action="${1:-show}"
    
    case "$action" in
        "show"|"list")
            ai_knowledge_show
            ;;
        "add")
            shift
            ai_knowledge_add "$@"
            ;;
        "search")
            shift
            ai_knowledge_search "$@"
            ;;
        "category")
            shift
            ai_knowledge_by_category "$@"
            ;;
        *)
            ai_knowledge_help
            ;;
    esac
}

# Show knowledge base
ai_knowledge_show() {
    echo "📚 AI Knowledge Base"
    echo "==================="
    echo ""
    
    local total_articles
    total_articles=$(jq -r '.metadata.total_articles' "$AI_KNOWLEDGE_DB")
    
    echo "Total articles: $total_articles"
    echo "Last updated: $(jq -r '.metadata.last_updated' "$AI_KNOWLEDGE_DB")"
    echo ""
    
    if [[ $total_articles -gt 0 ]]; then
        echo "Available articles:"
        jq -r '.articles[] | "[\(.category)] \(.title) (importance: \(.importance))"' "$AI_KNOWLEDGE_DB"
    else
        echo "No knowledge articles available."
    fi
}

# Add knowledge article
ai_knowledge_add() {
    local title="$1"
    local category="$2"
    local content="$3"
    local importance="${4:-5}"
    
    if [[ -z "$title" ]] || [[ -z "$category" ]] || [[ -z "$content" ]]; then
        echo "Usage: jb ai:knowledge add <title> <category> <content> [importance]"
        return 1
    fi
    
    local article_id
    article_id=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')
    
    local article
    article=$(jq -n \
        --arg id "$article_id" \
        --arg title "$title" \
        --arg category "$category" \
        --arg content "$content" \
        --arg created "$(date -Iseconds)" \
        --argjson importance "$importance" \
        '{
            id: $id,
            title: $title,
            category: $category,
            content: $content,
            created: $created,
            importance: $importance,
            tags: [],
            references: []
        }')
    
    # Add to knowledge base
    jq --argjson article "$article" \
        '.articles += [$article] | 
         .metadata.total_articles += 1 | 
         .metadata.last_updated = now | strftime("%Y-%m-%dT%H:%M:%S%z")' \
        "$AI_KNOWLEDGE_DB" > "${AI_KNOWLEDGE_DB}.tmp" && mv "${AI_KNOWLEDGE_DB}.tmp" "$AI_KNOWLEDGE_DB"
    
    echo "✅ Knowledge article added: $title"
    log_info "Added AI knowledge: $title" "AI"
}

# Search knowledge base
ai_knowledge_search() {
    local query="$1"
    
    if [[ -z "$query" ]]; then
        echo "Usage: jb ai:knowledge search <query>"
        return 1
    fi
    
    echo "🔍 Searching knowledge base for: $query"
    echo "======================================="
    echo ""
    
    jq -r --arg query "$query" \
        '.articles[] | select(.title + " " + .content | test($query; "i")) | 
         "[\(.category)] \(.title)\n\(.content)\n"' \
        "$AI_KNOWLEDGE_DB"
}

# Interactive chat interface
ai_chat() {
    echo "💬 AI Assistant Chat"
    echo "==================="
    echo ""
    echo "Welcome to the JB-VPS AI Assistant!"
    echo "I can help you with VPS management, security, and troubleshooting."
    echo "Type 'help' for commands, 'quit' to exit."
    echo ""
    
    local input
    while true; do
        echo -n "You: "
        read -r input
        
        case "$input" in
            "quit"|"exit"|"bye")
                echo "AI: Goodbye! Feel free to ask me anything anytime."
                break
                ;;
            "help")
                ai_chat_help
                ;;
            "memory")
                ai_memory_show
                ;;
            "knowledge")
                ai_knowledge_show
                ;;
            "status")
                echo "AI: Let me check your system status..."
                jb status
                ;;
            *)
                ai_process_chat_input "$input"
                ;;
        esac
        echo ""
    done
}

# Process chat input
ai_process_chat_input() {
    local input="$1"
    
    # Simple pattern matching for now
    case "$input" in
        *"security"*|*"harden"*)
            echo "AI: I can help with security! Here are some key security practices:"
            ai_knowledge_search "security"
            ;;
        *"backup"*|*"restore"*)
            echo "AI: Backup is crucial! Let me share what I know about backup strategies:"
            ai_knowledge_search "backup"
            ;;
        *"monitor"*|*"performance"*)
            echo "AI: System monitoring is important. Here's what I know:"
            ai_knowledge_search "monitoring"
            ;;
        *"ssh"*|*"key"*)
            echo "AI: SSH key management is essential for security:"
            ai_knowledge_search "ssh"
            ;;
        *)
            echo "AI: I'm still learning! Let me search my knowledge base for relevant information..."
            # Try to find relevant knowledge
            local results
            results=$(jq -r --arg query "$input" \
                '.articles[] | select(.content | test($query; "i")) | .title' \
                "$AI_KNOWLEDGE_DB" | head -3)
            
            if [[ -n "$results" ]]; then
                echo "AI: I found some relevant information:"
                echo "$results"
            else
                echo "AI: I don't have specific information about that yet, but I'm learning!"
                echo "AI: You can teach me by using 'jb ai:learn' or add to my knowledge base."
            fi
            ;;
    esac
    
    # Log the interaction
    ai_log_interaction "$input"
}

# Chat help
ai_chat_help() {
    echo "AI: Here are the commands I understand:"
    echo "  • help - Show this help"
    echo "  • memory - Show my memory"
    echo "  • knowledge - Show my knowledge base"
    echo "  • status - Check system status"
    echo "  • quit/exit/bye - End chat"
    echo ""
    echo "I can also help with topics like:"
    echo "  • Security and hardening"
    echo "  • System monitoring"
    echo "  • SSH and authentication"
    echo "  • Backup and recovery"
    echo "  • General VPS management"
}

# Learning session
ai_learn() {
    echo "📝 AI Learning Session"
    echo "====================="
    echo ""
    echo "Teach me something new! I'll remember it for future reference."
    echo "Type 'done' when finished."
    echo ""
    
    local topic category content
    
    echo -n "What topic would you like to teach me about? "
    read -r topic
    
    echo -n "What category does this belong to? (system_administration/security/networking/etc.) "
    read -r category
    
    echo "Please provide the information (you can use multiple lines, type 'END' on a new line when done):"
    content=""
    while IFS= read -r line; do
        if [[ "$line" == "END" ]]; then
            break
        fi
        content+="$line"$'\n'
    done
    
    # Add to knowledge base
    ai_knowledge_add "$topic" "$category" "$content" 7
    
    # Also add to memory
    ai_memory_add "learning" "User taught me about: $topic" 8
    
    echo ""
    echo "✅ Thank you for teaching me about '$topic'!"
    echo "I've added this to my knowledge base and will remember it."
}

# Query knowledge with context
ai_query() {
    local query="$1"
    
    if [[ -z "$query" ]]; then
        echo "Usage: jb ai:query <question>"
        echo "Example: jb ai:query 'How do I secure SSH?'"
        return 1
    fi
    
    echo "🤖 AI Query Response"
    echo "==================="
    echo ""
    echo "Query: $query"
    echo ""
    
    # Search knowledge base
    local knowledge_results
    knowledge_results=$(jq -r --arg query "$query" \
        '.articles[] | select(.title + " " + .content | test($query; "i")) | 
         "📖 \(.title) (\(.category))\n\(.content)\n"' \
        "$AI_KNOWLEDGE_DB")
    
    # Search memory
    local memory_results
    memory_results=$(jq -r --arg query "$query" \
        '.memories[] | select(.content | test($query; "i")) | 
         "🧠 [\(.category)] \(.content)"' \
        "$AI_MEMORY_DB")
    
    if [[ -n "$knowledge_results" ]]; then
        echo "From my knowledge base:"
        echo "$knowledge_results"
    fi
    
    if [[ -n "$memory_results" ]]; then
        echo "From my memory:"
        echo "$memory_results"
    fi
    
    if [[ -z "$knowledge_results" ]] && [[ -z "$memory_results" ]]; then
        echo "I don't have specific information about that query."
        echo "You can teach me using 'jb ai:learn' or add knowledge with 'jb ai:knowledge add'."
    fi
    
    # Log the query
    ai_log_interaction "query: $query"
}

# Configuration management
ai_config() {
    local action="${1:-show}"
    
    case "$action" in
        "show")
            echo "⚙️ AI Configuration"
            echo "=================="
            echo ""
            jq '.' "$AI_CONFIG_FILE"
            ;;
        "edit")
            echo "Opening AI configuration for editing..."
            "${EDITOR:-nano}" "$AI_CONFIG_FILE"
            ;;
        *)
            echo "Usage: jb ai:config [show|edit]"
            ;;
    esac
}

# Sync memory across sessions
ai_sync() {
    echo "🔄 Syncing AI Memory"
    echo "==================="
    echo ""
    
    # Archive current session
    if [[ -f "$AI_CURRENT_SESSION" ]]; then
        local session_id
        session_id=$(jq -r '.session_id' "$AI_CURRENT_SESSION")
        cp "$AI_CURRENT_SESSION" "$AI_SESSIONS_DIR/${session_id}.json"
        echo "✅ Archived session: $session_id"
    fi
    
    # Start new session
    ai_start_session
    echo "✅ Started new session"
    
    # Cleanup old sessions (keep last 50)
    find "$AI_SESSIONS_DIR" -name "session_*.json" -type f | sort | head -n -50 | xargs rm -f 2>/dev/null || true
    echo "✅ Cleaned up old sessions"
    
    echo ""
    echo "Memory sync completed!"
}

# Log interaction
ai_log_interaction() {
    local interaction="$1"
    local timestamp=$(date -Iseconds)
    
    if [[ -f "$AI_CURRENT_SESSION" ]]; then
        jq --arg interaction "$interaction" --arg timestamp "$timestamp" \
            '.interactions += [{"timestamp": $timestamp, "content": $interaction}]' \
            "$AI_CURRENT_SESSION" > "${AI_CURRENT_SESSION}.tmp" && mv "${AI_CURRENT_SESSION}.tmp" "$AI_CURRENT_SESSION"
    fi
}

# Help functions
ai_memory_help() {
    echo "🧠 AI Memory Commands"
    echo "===================="
    echo ""
    echo "jb ai:memory show     - Show recent memories"
    echo "jb ai:memory add      - Add new memory entry"
    echo "jb ai:memory search   - Search memory"
    echo "jb ai:memory stats    - Show memory statistics"
    echo "jb ai:memory cleanup  - Clean up old memories"
}

ai_knowledge_help() {
    echo "📚 AI Knowledge Commands"
    echo "======================="
    echo ""
    echo "jb ai:knowledge show     - Show knowledge base"
    echo "jb ai:knowledge add      - Add knowledge article"
    echo "jb ai:knowledge search   - Search knowledge"
    echo "jb ai:knowledge category - Show by category"
}

# Memory cleanup
ai_memory_cleanup() {
    echo "🧹 Cleaning up AI memory..."
    
    local retention_days
    retention_days=$(jq -r '.memory.retention_days' "$AI_CONFIG_FILE")
    
    local cutoff_date
    cutoff_date=$(date -d "$retention_days days ago" -Iseconds)
    
    # Remove old memories
    jq --arg cutoff "$cutoff_date" \
        '.memories = [.memories[] | select(.timestamp > $cutoff)] |
         .metadata.total_entries = (.memories | length) |
         .metadata.last_updated = now | strftime("%Y-%m-%dT%H:%M:%S%z")' \
        "$AI_MEMORY_DB" > "${AI_MEMORY_DB}.tmp" && mv "${AI_MEMORY_DB}.tmp" "$AI_MEMORY_DB"
    
    echo "✅ Memory cleanup completed"
}

# Register AI commands
jb_register "ai:memory" ai_memory "Manage AI persistent memory" "ai"
jb_register "ai:knowledge" ai_knowledge "Manage AI knowledge base" "ai"
jb_register "ai:chat" ai_chat "Interactive chat with AI assistant" "ai"
jb_register "ai:learn" ai_learn "Teach AI new information" "ai"
jb_register "ai:query" ai_query "Query AI knowledge and memory" "ai"
jb_register "ai:stats" ai_memory_stats "Show AI memory statistics" "ai"
jb_register "ai:config" ai_config "Manage AI configuration" "ai"
jb_register "ai:sync" ai_sync "Synchronize AI memory across sessions" "ai"

# Initialize AI plugin
ai_init
