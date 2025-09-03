#!/bin/bash
# AI Plugin for JB-VPS
# Integrates with MnemosyneOS/Lucian Voss

# Define constants
MNEMO_HOST="127.0.0.1"
MNEMO_PORT="8077"
MNEMO_API="http://${MNEMO_HOST}:${MNEMO_PORT}"
CONFIG_FILE="/etc/jb-vps/ai.env"

# Require the base library
. "${JB_ROOT}/lib/base.sh"

# Plugin metadata
plugin_name="ai"
plugin_description="AI Assistant (Lucian Voss)"
plugin_version="2.0.0"

# Function to check if the Mnemosyne service is running
check_mnemo_service() {
    if ! curl -s "${MNEMO_API}/health" > /dev/null; then
        echo_error "Mnemosyne service is not running"
        echo_info "Run 'sudo systemctl start mnemo.service' to start it"
        return 1
    fi
    return 0
}

# Function to execute commands with preview support
with_preview() {
    local command="$1"
    local description="$2"
    
    if [[ "$3" == "--preview" ]]; then
        echo_info "PREVIEW: ${description}"
        return 0
    else
        ${command}
        return $?
    fi
}

#
# Command functions
#

# Command: jb ai:config - Configure the AI service
cmd_config() {
    local preview=""
    
    if [[ "$1" == "--preview" ]]; then
        preview="--preview"
        echo_info "PREVIEW: Configuring AI settings at ${CONFIG_FILE}"
        return 0
    fi
    
    # Check if config file exists
    if [[ -f "${CONFIG_FILE}" ]]; then
        echo_info "Editing existing config file: ${CONFIG_FILE}"
        sudo ${EDITOR:-nano} "${CONFIG_FILE}"
    else
        echo_error "Config file not found: ${CONFIG_FILE}"
        echo_info "Run 'installers/install-mnemo.sh' to create the config file"
        return 1
    fi
    
    echo_success "Configuration updated"
    echo_info "Restart the service with: sudo systemctl restart mnemo.service"
    return 0
}

# Command: jb ai:ingest-docs - Ingest documentation from a path
cmd_ingest_docs() {
    local path="$1"
    local recursive="true"
    local preview=""
    
    # Check for preview flag
    if [[ "$1" == "--preview" ]]; then
        preview="--preview"
        shift
        path="$1"
        echo_info "PREVIEW: Ingesting documents from ${path:-"(no path specified)"}"
        return 0
    fi
    
    # Check for path
    if [[ -z "${path}" ]]; then
        echo_error "No path specified"
        echo_info "Usage: jb ai:ingest-docs [--preview] <path>"
        return 1
    fi
    
    # Check if path exists
    if [[ ! -e "${path}" ]]; then
        echo_error "Path does not exist: ${path}"
        return 1
    fi
    
    # Check if service is running
    check_mnemo_service || return 1
    
    echo_info "Ingesting documents from: ${path}"
    
    # Call the API to ingest documents
    local response=$(curl -s -X POST \
        "${MNEMO_API}/kb/ingest" \
        -H "Content-Type: application/json" \
        -d "{\"path\":\"${path}\",\"recursive\":${recursive}}")
    
    # Check response
    if [[ $(echo "${response}" | jq -r '.status') == "ingestion_started" ]]; then
        echo_success "Document ingestion started"
        echo_info "Path: ${path}"
        echo_info "This process runs in the background and may take some time"
    else
        echo_error "Failed to start document ingestion"
        echo_info "Response: ${response}"
        return 1
    fi
    
    return 0
}

# Command: jb ai:remember - Store a memory
cmd_remember() {
    local content="$1"
    local preview=""
    
    # Check for preview flag
    if [[ "$1" == "--preview" ]]; then
        preview="--preview"
        shift
        content="$1"
        echo_info "PREVIEW: Storing memory: ${content:-"(no content specified)"}"
        return 0
    fi
    
    # Check for content
    if [[ -z "${content}" ]]; then
        echo_error "No content specified"
        echo_info "Usage: jb ai:remember [--preview] \"<content>\""
        return 1
    fi
    
    # Check if service is running
    check_mnemo_service || return 1
    
    echo_info "Storing memory..."
    
    # Call the API to store memory
    local response=$(curl -s -X POST \
        "${MNEMO_API}/memory/remember" \
        -H "Content-Type: application/json" \
        -d "{\"content\":\"${content}\",\"tags\":[\"cli\",\"user_input\"]}")
    
    # Check response
    if [[ $(echo "${response}" | jq -r '.status') == "success" ]]; then
        echo_success "Memory stored successfully"
        echo_info "ID: $(echo "${response}" | jq -r '.id')"
        echo_info "Type: $(echo "${response}" | jq -r '.memory_type')"
    else
        echo_error "Failed to store memory"
        echo_info "Response: ${response}"
        return 1
    fi
    
    return 0
}

# Command: jb ai:reflect - Generate reflections
cmd_reflect() {
    local preview=""
    
    # Check for preview flag
    if [[ "$1" == "--preview" ]]; then
        preview="--preview"
        echo_info "PREVIEW: Generating reflections"
        return 0
    fi
    
    # Check if service is running
    check_mnemo_service || return 1
    
    echo_info "Generating reflections..."
    
    # Call the API to generate reflections
    local response=$(curl -s -X POST \
        "${MNEMO_API}/memory/reflect" \
        -H "Content-Type: application/json" \
        -d "{}")
    
    # Check response
    if [[ $(echo "${response}" | jq -r '.status') == "reflection_started" ]]; then
        echo_success "Reflection process started"
        echo_info "This process runs in the background and may take some time"
    else
        echo_error "Failed to start reflection process"
        echo_info "Response: ${response}"
        return 1
    fi
    
    return 0
}

# Command: jb ai:recall - Recall memories
cmd_recall() {
    local query="$1"
    local preview=""
    
    # Check for preview flag
    if [[ "$1" == "--preview" ]]; then
        preview="--preview"
        shift
        query="$1"
        echo_info "PREVIEW: Recalling memories for query: ${query:-"(no query specified)"}"
        return 0
    fi
    
    # Check for query
    if [[ -z "${query}" ]]; then
        echo_error "No query specified"
        echo_info "Usage: jb ai:recall [--preview] \"<query>\""
        return 1
    fi
    
    # Check if service is running
    check_mnemo_service || return 1
    
    echo_info "Recalling memories for query: ${query}"
    
    # Call the API to recall memories
    local response=$(curl -s -G \
        "${MNEMO_API}/memory/recall" \
        --data-urlencode "query=${query}" \
        -d "limit=5")
    
    # Check response
    if [[ $(echo "${response}" | jq -r '.status') == "success" ]]; then
        echo_success "Found $(echo "${response}" | jq -r '.count') memories"
        
        # Display results
        echo "${response}" | jq -r '.results[] | "\n[\(.metadata.memory_type // "unknown")] Relevance: \(.relevance):\n\(.content)\n"'
    else
        echo_error "Failed to recall memories"
        echo_info "Response: ${response}"
        return 1
    fi
    
    return 0
}

# Command: jb ai:rss:add - Add RSS feed
cmd_rss_add() {
    local url="$1"
    local preview=""
    
    # Check for preview flag
    if [[ "$1" == "--preview" ]]; then
        preview="--preview"
        shift
        url="$1"
        echo_info "PREVIEW: Adding RSS feed: ${url:-"(no URL specified)"}"
        return 0
    fi
    
    # Check for URL
    if [[ -z "${url}" ]]; then
        echo_error "No URL specified"
        echo_info "Usage: jb ai:rss:add [--preview] <url>"
        return 1
    fi
    
    # Check if service is running
    check_mnemo_service || return 1
    
    echo_info "Adding RSS feed: ${url}"
    
    # Call the API to add RSS feed
    local response=$(curl -s -X POST \
        "${MNEMO_API}/rss/add" \
        -H "Content-Type: application/json" \
        -d "{\"url\":\"${url}\"}")
    
    # Check response
    if [[ $(echo "${response}" | jq -r '.status') == "success" ]]; then
        echo_success "RSS feed added successfully"
        echo_info "Feed ID: $(echo "${response}" | jq -r '.feed_id')"
    else
        echo_error "Failed to add RSS feed"
        echo_info "Response: ${response}"
        return 1
    fi
    
    return 0
}

# Command: jb ai:rss:pull-now - Pull RSS feeds immediately
cmd_rss_pull_now() {
    local preview=""
    
    # Check for preview flag
    if [[ "$1" == "--preview" ]]; then
        preview="--preview"
        echo_info "PREVIEW: Pulling RSS feeds immediately"
        return 0
    fi
    
    # Check if service is running
    check_mnemo_service || return 1
    
    echo_info "Pulling RSS feeds..."
    
    # Call the API to pull RSS feeds
    local response=$(curl -s -X POST \
        "${MNEMO_API}/rss/pull-now" \
        -H "Content-Type: application/json" \
        -d "{}")
    
    # Check response
    if [[ $(echo "${response}" | jq -r '.status') == "rss_pull_started" ]]; then
        echo_success "RSS pull started"
        echo_info "This process runs in the background and may take some time"
    else
        echo_error "Failed to start RSS pull"
        echo_info "Response: ${response}"
        return 1
    fi
    
    return 0
}

# Command: jb ai:status - Check the status of the AI service
cmd_status() {
    local preview=""
    
    # Check for preview flag
    if [[ "$1" == "--preview" ]]; then
        preview="--preview"
        echo_info "PREVIEW: Checking AI service status"
        return 0
    fi
    
    echo_info "Checking AI service status..."
    
    # Check if service is running
    if check_mnemo_service; then
        # Get health information
        local health_response=$(curl -s "${MNEMO_API}/health")
        local config_response=$(curl -s "${MNEMO_API}/config")
        local stats_response=$(curl -s "${MNEMO_API}/meta/stats")
        
        echo_success "AI service is running"
        echo_info "Version: $(echo "${health_response}" | jq -r '.version')"
        echo_info "Provider: $(echo "${config_response}" | jq -r '.provider')"
        echo_info "Total memories: $(echo "${stats_response}" | jq -r '.total_memory_count')"
        
        # Display memory layer counts
        echo_info "Memory layers:"
        for layer in semantic episodic procedural reflective affective identity; do
            local count=$(echo "${stats_response}" | jq -r ".memory_layers.${layer}.count // 0")
            echo_info "  - ${layer}: ${count} items"
        done
    else
        echo_error "AI service is not running"
    fi
    
    return 0
}

# Register plugin commands
register_command "ai:config" "Configure AI settings" "cmd_config"
register_command "ai:ingest-docs" "Ingest documents into AI memory" "cmd_ingest_docs"
register_command "ai:remember" "Store a memory" "cmd_remember"
register_command "ai:reflect" "Generate reflections on memories" "cmd_reflect"
register_command "ai:recall" "Recall memories by query" "cmd_recall"
register_command "ai:rss:add" "Add an RSS feed" "cmd_rss_add"
register_command "ai:rss:pull-now" "Pull RSS feeds immediately" "cmd_rss_pull_now"
register_command "ai:status" "Check AI service status" "cmd_status"
