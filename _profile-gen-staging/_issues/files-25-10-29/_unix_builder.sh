#!/bin/bash
# ============================================================================
# Unix Profile Generator v17.0 (Simplified - Single Home)
# ============================================================================
# Description: Generates bash and zsh profiles from JSON configuration
# Input: JSON configuration via stdin
# Output: Generated .bashrc and .zshrc files
# Simplified: No HOME override, workspace IS home
# ============================================================================

set -e
set -o pipefail

# ============================================================================
# PREREQUISITES CHECK
# ============================================================================

if ! command -v jq &> /dev/null; then
    echo "ERROR: 'jq' is not installed." >&2
    echo "Install with: sudo apt-get install jq" >&2
    exit 1
fi

# ============================================================================
# READ CONFIGURATION
# ============================================================================

CONFIG_JSON=$(cat)

if [ -z "$CONFIG_JSON" ] || [ "$CONFIG_JSON" = "null" ]; then
    echo "ERROR: No configuration received via stdin" >&2
    exit 1
fi

# ============================================================================
# FUNCTION GENERATORS
# ============================================================================

generate_check_versions() {
    local secrets_check=""
    secrets_check=$(echo "$CONFIG_JSON" | jq -r '.secure_env.required[]?.name' 2>/dev/null | while read -r secret_name; do
        if [ -n "$secret_name" ]; then
            printf "    if [ -n \"\${%s}\" ]; then\n" "$secret_name"
            printf "        echo \"  [OK] %s: SET\"\n" "$secret_name"
            printf "    else\n"
            printf "        echo \"  [X] %s: NOT SET\"\n" "$secret_name"
            printf "    fi\n"
        fi
    done)

    cat <<EOF
function check_versions() {
    echo ""
    echo "Tool Version Check"
    echo "===================="
    
    if command -v node >/dev/null 2>&1; then
        echo "  [OK] Node.js: \$(node --version)"
    else
        echo "  [X] Node.js: Not found"
    fi
    
    if command -v python3 >/dev/null 2>&1; then
        echo "  [OK] Python3: \$(python3 --version 2>&1)"
    else
        echo "  [X] Python3: Not found"
    fi
    
    if command -v git >/dev/null 2>&1; then
        echo "  [OK] Git: \$(git --version)"
    else
        echo "  [X] Git: Not found"
    fi
    
    echo ""
    echo "Environment Variables:"
    echo "======================"
${secrets_check}
    echo ""
}
EOF
}

generate_show_env() {
    cat <<'EOF'
function show_env() {
    echo ""
    echo "Linux Development Environment"
    echo "=============================="
    echo "Platform: WSL Debian"
    echo "User: $USERNAME"
    echo "Home: $HOME"
    echo "Workspace: $HOME"
    echo "Node Options: $NODE_OPTIONS"
    echo ""
}
EOF
}

generate_topic_commands() {
    local helpers_json=$(echo "$CONFIG_JSON" | jq -c '.helpers.helpers // empty')
    
    if [ -z "$helpers_json" ] || [ "$helpers_json" = "null" ]; then
        cat <<'EOF'
function show_commands() {
    echo "No helper commands configured"
}
EOF
        return
    fi
    
    cat <<'EOF'
function show_commands() {
    local topic=$1
    
    if [ -z "$topic" ]; then
        echo "Usage: show_commands <topic>"
EOF
    
    local topics=$(echo "$helpers_json" | jq -r 'keys[]' | tr '\n' ',' | sed 's/,$//')
    printf "        echo \"Available topics: %s\"\n" "$topics"
    
    cat <<'EOF'
        return
    fi
    
    case "$topic" in
EOF
    
    echo "$helpers_json" | jq -r 'keys[]' | while read -r topic; do
        local topic_data=$(echo "$helpers_json" | jq -c ".\"$topic\".bash // empty")
        
        if [ -n "$topic_data" ] && [ "$topic_data" != "null" ]; then
            local title=$(echo "$topic_data" | jq -r '.title')
            
            printf "        %s)\n" "$topic"
            printf "            echo \"\"\n"
            printf "            echo \"%s\"\n" "$title"
            printf "            echo \"%s\"\n" "$(echo "$title" | sed 's/./=/g')"
            
            echo "$topic_data" | jq -c '.sections[]' | while read -r section; do
                local heading=$(echo "$section" | jq -r '.heading')
                printf "            echo \"\"\n"
                printf "            echo \"%s\"\n" "$heading"
                
                echo "$section" | jq -c '.commands[]' | while read -r cmd; do
                    local name=$(echo "$cmd" | jq -r '.name')
                    local desc=$(echo "$cmd" | jq -r '.description')
                    printf "            printf '  %%-40s - %%s\\n' %q %q\n" "$name" "$desc"
                done
            done
            
            printf "            ;;\n"
        fi
    done
    
    cat <<'EOF'
        *)
            echo "Unknown topic: $topic"
EOF
    printf "            echo \"Available topics: %s\"\n" "$topics"
    cat <<'EOF'
            ;;
    esac
    echo ""
}
EOF
}

generate_topic_examples() {
    local examples_json=$(echo "$CONFIG_JSON" | jq -c '.helpers.examples // empty')
    
    if [ -z "$examples_json" ] || [ "$examples_json" = "null" ]; then
        cat <<'EOF'
function show_examples() {
    echo "No examples configured"
}
EOF
        return
    fi
    
    cat <<'EOF'
function show_examples() {
    local topic=$1
    
    if [ -z "$topic" ]; then
        echo "Usage: show_examples <topic>"
EOF
    
    local topics=$(echo "$examples_json" | jq -r 'keys[]' | tr '\n' ',' | sed 's/,$//')
    printf "        echo \"Available topics: %s\"\n" "$topics"
    
    cat <<'EOF'
        return
    fi
    
    case "$topic" in
EOF
    
    echo "$examples_json" | jq -r 'keys[]' | while read -r topic; do
        local topic_data=$(echo "$examples_json" | jq -c ".\"$topic\".bash // empty")
        
        if [ -n "$topic_data" ] && [ "$topic_data" != "null" ]; then
            local title=$(echo "$topic_data" | jq -r '.title')
            
            printf "        %s)\n" "$topic"
            printf "            echo \"\"\n"
            printf "            echo \"%s\"\n" "$title"
            printf "            echo \"%s\"\n" "$(echo "$title" | sed 's/./=/g')"
            
            echo "$topic_data" | jq -c '.sections[]' | while read -r section; do
                local heading=$(echo "$section" | jq -r '.heading')
                printf "            echo \"\"\n"
                printf "            echo \"%s\"\n" "$heading"
                
                echo "$section" | jq -c '.examples[]' | while read -r ex; do
                    local title=$(echo "$ex" | jq -r '.title')
                    local snippet=$(echo "$ex" | jq -r '.snippet')
                    printf "            printf '  %%-40s - %%s\\n' %q %q\n" "$title" "$snippet"
                done
            done
            
            printf "            ;;\n"
        fi
    done
    
    cat <<'EOF'
        *)
            echo "Unknown topic: $topic"
EOF
    printf "            echo \"Available topics: %s\"\n" "$topics"
    cat <<'EOF'
            ;;
    esac
    echo ""
}
EOF
}

# ============================================================================
# PROFILE CONTENT BUILDER
# ============================================================================

build_profile_content() {
    local shell_type=$1
    local shell_rc=$2

    local WORKSPACE
    local SECRETS_FILE
    local ENV_USERNAME
    local ENV_AMP_PROJECT
    local ENV_NODE_OPTIONS
    local NODE_EXE_PATH
    local NPM_EXE_PATH
    local NPX_EXE_PATH
    
    WORKSPACE=$(echo "$CONFIG_JSON" | jq -r '.workspace')
    SECRETS_FILE=$(echo "$CONFIG_JSON" | jq -r '.secretsFile')
    ENV_USERNAME=$(echo "$CONFIG_JSON" | jq -r '.envUsername')
    ENV_AMP_PROJECT=$(echo "$CONFIG_JSON" | jq -r '.envAmpProject')
    ENV_NODE_OPTIONS=$(echo "$CONFIG_JSON" | jq -r '.envNodeOptions')
    NODE_EXE_PATH=$(echo "$CONFIG_JSON" | jq -r '.nodeExePath // empty')
    NPM_EXE_PATH=$(echo "$CONFIG_JSON" | jq -r '.npmExePath // empty')
    NPX_EXE_PATH=$(echo "$CONFIG_JSON" | jq -r '.npxExePath // empty')

    local CHECK_VERSIONS_FUNC
    local SHOW_ENV_FUNC
    local SHOW_COMMANDS_FUNC
    local SHOW_EXAMPLES_FUNC
    
    CHECK_VERSIONS_FUNC=$(generate_check_versions)
    SHOW_ENV_FUNC=$(generate_show_env)
    SHOW_COMMANDS_FUNC=$(generate_topic_commands)
    SHOW_EXAMPLES_FUNC=$(generate_topic_examples)

    local NODE_WRAPPERS=""
    if [ -n "$NODE_EXE_PATH" ]; then
        local NPM_WIN_PATH=$(echo "$NPM_EXE_PATH" | sed 's|/mnt/\([a-z]\)/|\U\1:/|g')
        local NPX_WIN_PATH=$(echo "$NPX_EXE_PATH" | sed 's|/mnt/\([a-z]\)/|\U\1:/|g')

        NODE_WRAPPERS="
# --- Node.js Wrappers (Windows executables via WSL) ---
function node() {
\"$NODE_EXE_PATH\" \"\$@\"
}

function npm() {
(cd /mnt/c && cmd.exe /c \"$NPM_WIN_PATH\" \"\$@\")
}

function npx() {
(cd /mnt/c && cmd.exe /c \"$NPX_WIN_PATH\" \"\$@\")
}
"
    fi

    local NAV_FUNCTIONS=""
    local nav_config=$(echo "$CONFIG_JSON" | jq -c '.navigation // empty')

    if [ -n "$nav_config" ] && [ "$nav_config" != "null" ]; then
        NAV_FUNCTIONS="
# --- Navigation Shortcuts ---"
        
        while IFS='=' read -r name path; do
            NAV_FUNCTIONS="${NAV_FUNCTIONS}
function ${name}() {
    cd \"${path}\"
}
"
        done < <(echo "$nav_config" | jq -r 'to_entries[] | "\(.key)=\(.value)"')
    fi

    cat <<EOF
# ============================================================================
# GENERATED FILE - DO NOT EDIT MANUALLY
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# Shell: $shell_type ($shell_rc)
# ============================================================================

# --- Environment Variables ---
export WORKSPACE="$WORKSPACE"
export USERNAME="$ENV_USERNAME"
export AMP_DEV_PROJECT="$ENV_AMP_PROJECT"
export NODE_OPTIONS="$ENV_NODE_OPTIONS"

# --- Custom Prompt ---
export PS1='$ '

# --- Load Secrets ---
if [ -f "$SECRETS_FILE" ]; then
    set -a
    . "$SECRETS_FILE"
    set +a
fi

# --- Core Functions ---
$CHECK_VERSIONS_FUNC

$SHOW_ENV_FUNC

$SHOW_COMMANDS_FUNC

$SHOW_EXAMPLES_FUNC

$NODE_WRAPPERS

$NAV_FUNCTIONS

# --- Aliases ---
alias check_env='source ~/.$shell_rc'

# --- Startup Sequence ---
clear
show_env

printf '%s\n' "Run 'check_versions' to verify tool setup."
printf '%s\n' "Run 'check_env' to refresh."
printf '%s\n' "Run 'show_commands <topic>' for topic-specific commands."
printf '%s\n' "Run 'show_examples <topic>' for topic-specific examples."
printf '\n'

EOF
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

echo "Unix Profile Generator: Starting..." >&2

BASH_OUT_PATH=$(echo "$CONFIG_JSON" | jq -r '.bashOutPath')
ZSH_OUT_PATH=$(echo "$CONFIG_JSON" | jq -r '.zshOutPath')

if [ -z "$BASH_OUT_PATH" ] || [ "$BASH_OUT_PATH" = "null" ]; then
    echo "ERROR: bashOutPath not found in configuration" >&2
    exit 1
fi

if [ -z "$ZSH_OUT_PATH" ] || [ "$ZSH_OUT_PATH" = "null" ]; then
    echo "ERROR: zshOutPath not found in configuration" >&2
    exit 1
fi

BASH_OUT_DIR=$(dirname "$BASH_OUT_PATH")
ZSH_OUT_DIR=$(dirname "$ZSH_OUT_PATH")

mkdir -p "$BASH_OUT_DIR" 2>/dev/null || true
mkdir -p "$ZSH_OUT_DIR" 2>/dev/null || true

echo "Unix Profile Generator: Building Debian/Bash profile..." >&2
build_profile_content "Debian" "bashrc" > "$BASH_OUT_PATH"
echo "Unix Profile Generator: [OK] Written to $BASH_OUT_PATH" >&2

echo "Unix Profile Generator: Building Zsh profile..." >&2
build_profile_content "Zsh" "zshrc" > "$ZSH_OUT_PATH"
echo "Unix Profile Generator: [OK] Written to $ZSH_OUT_PATH" >&2

echo "Unix Profile Generator: Complete!" >&2
exit 0