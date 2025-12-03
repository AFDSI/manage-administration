#!/bin/bash
# ============================================================================
# Unix Profile Generator v16.0 (Claude Refactor)
# ============================================================================
# Description: Generates bash and zsh profiles from JSON configuration
# Input: JSON configuration via stdin
# Output: Generated .bashrc and .zshrc files
# WSL 1 Compatible: No Unicode/emoji characters
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
    # Extract required secrets from config
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
    echo "Platform: WSL Debian/Ubuntu"
    echo "User: $USERNAME"
    echo "Home: $HOME"
    echo "Dev Home: $DEV_HOME"
    echo "AMP Project: $AMP_DEV_PROJECT"
    echo "Node Options: $NODE_OPTIONS"
    echo ""
}
EOF
}

generate_reference_function() {
    local func_name=$1
    local json_node_path=$2

    # Extract the JSON node for this function
    local json_node
    json_node=$(echo "$CONFIG_JSON" | jq -c "$json_node_path")
    
    # Check if node exists and is not null
    if [ -z "$json_node" ] || [ "$json_node" = "null" ]; then
        cat <<EOF
function $func_name() {
    echo "No content defined for this mode."
}
EOF
        return
    fi

    # Extract title
    local title
    title=$(echo "$json_node" | jq -r '.title')
    
    # Generate the function body
    local body
    body=$(echo "$json_node" \
        | jq -c '(if .sections | type=="array" then .sections[] else .sections end)?' \
        | while read -r section; do
            # Get section heading
            local heading
            heading=$(echo "$section" | jq -r '.heading')
            printf "    echo \"\"\n"
            printf "    echo \"%s\"\n" "$heading"
            
            # Handle different section types
            if [[ $(echo "$section" | jq 'has("commands")') == "true" ]]; then
                # Commands section
                echo "$section" | jq -c '(if .commands | type=="array" then .commands[] else .commands end)?' \
                | while read -r item; do
                    local cmd_name
                    local cmd_desc
                    cmd_name=$(echo "$item" | jq -r '.name')
                    cmd_desc=$(echo "$item" | jq -r '.description')
                    printf "    printf '  %%-30s - %%s\\n' %q %q\n" "$cmd_name" "$cmd_desc"
                done

            elif [[ $(echo "$section" | jq 'has("examples")') == "true" ]]; then
                # Examples section
                echo "$section" | jq -c '(if .examples | type=="array" then .examples[] else .examples end)?' \
                | while read -r item; do
                    local ex_title
                    local ex_snippet
                    ex_title=$(echo "$item" | jq -r '.title')
                    ex_snippet=$(echo "$item" | jq -r '.snippet')
                    printf "    printf '  %%-30s - %%s\\n' %q %q\n" "$ex_title" "$ex_snippet"
                done

            elif [[ $(echo "$section" | jq 'has("parameters")') == "true" ]]; then
                # Parameters section (detailed command)
                local cmd
                local desc
                cmd=$(echo "$section" | jq -r '.command')
                desc=$(echo "$section" | jq -r '.description')
                
                printf "    echo \"  Command: %s\"\n" "$cmd"
                printf "    echo \"  Description: %s\"\n" "$desc"
                printf "    echo \"  Parameters:\"\n"
                
                echo "$section" | jq -c '(if .parameters | type=="array" then .parameters[] else .parameters end)?' \
                | while read -r param; do
                    local flag
                    local param_desc
                    flag=$(echo "$param" | jq -r '.flag')
                    param_desc=$(echo "$param" | jq -r '.desc')
                    printf "    printf '    %%-25s - %%s\\n' %q %q\n" "$flag" "$param_desc"
                done
            fi
        done)

    # Output the complete function
    printf "function %s() {\n" "$func_name"
    printf "    echo \"\"\n"
    printf "    echo \"%s\"\n" "$title"
    printf "    echo \"%s\"\n" "$(echo "$title" | sed 's/./=/g')"
    printf "%s\n" "$body"
    printf "    echo \"\"\n"
    printf "}\n"
}

# ============================================================================
# PROFILE CONTENT BUILDER
# ============================================================================

build_profile_content() {
    local shell_type=$1   # Debian | Zsh
    local shell_rc=$2     # bashrc | zshrc

    # Extract configuration values
    local DEV_HOME
    local SECRETS_FILE
    local ENV_USERNAME
    local ENV_AMP_PROJECT
    local ENV_NODE_OPTIONS
    local STARTUP_FOOTER
    local NODE_EXE_PATH
    local NPM_EXE_PATH
    local NPX_EXE_PATH
    
    DEV_HOME=$(echo "$CONFIG_JSON" | jq -r '.devHome')
    SECRETS_FILE=$(echo "$CONFIG_JSON" | jq -r '.secretsFile')
    ENV_USERNAME=$(echo "$CONFIG_JSON" | jq -r '.envUsername')
    ENV_AMP_PROJECT=$(echo "$CONFIG_JSON" | jq -r '.envAmpProject')
    ENV_NODE_OPTIONS=$(echo "$CONFIG_JSON" | jq -r '.envNodeOptions')
    STARTUP_FOOTER=$(echo "$CONFIG_JSON" | jq -r '.interface.startup_footer')

    # Generate function content
    local CHECK_VERSIONS_FUNC
    local SHOW_ENV_FUNC
    local SHOW_COMMANDS_FUNC
    local SHOW_EXAMPLES_FUNC
    
    CHECK_VERSIONS_FUNC=$(generate_check_versions)
    SHOW_ENV_FUNC=$(generate_show_env)
    SHOW_COMMANDS_FUNC=$(generate_reference_function "show_commands" ".interface.command_reference.modes.$shell_type")
    SHOW_EXAMPLES_FUNC=$(generate_reference_function "show_examples" ".interface.examples_reference.modes.$shell_type")


# Generate nvm initialization (native WSL Node.js)
local NVM_INIT='
# --- nvm Initialization (Native WSL Node.js) ---
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
'
# Generate pyenv initialization (native WSL Python)
local PYENV_INIT='
# --- pyenv Initialization (Native WSL Python) ---
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
if command -v pyenv 1>/dev/null 2>&1; then
  eval "$(pyenv init -)"
fi
'

# Generate navigation functions if configured
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

    # Build the complete profile
    cat <<EOF
# ============================================================================
# GENERATED FILE - DO NOT EDIT MANUALLY
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# Shell: $shell_type ($shell_rc)
# ============================================================================

# --- Environment Variables ---
export DEV_HOME="$DEV_HOME"
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

$NVM_INIT

$PYENV_INIT

$NAV_FUNCTIONS

# --- Aliases ---
alias sc='show_commands'
alias se='show_examples'
alias check_env='source ~/.$shell_rc'

# --- Startup Sequence ---
clear
show_env

printf '%s\n' "Run 'check_versions' to verify tool setup or 'check_env' to refresh."
printf '%s\n' "Run 'show_commands' for platform-specific commands."
printf '%s\n' "Run 'show_examples' for command examples."
printf '\n'

EOF
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

echo "Unix Profile Generator: Starting..." >&2

# Extract output paths from configuration
BASH_OUT_PATH=$(echo "$CONFIG_JSON" | jq -r '.bashOutPath')
ZSH_OUT_PATH=$(echo "$CONFIG_JSON" | jq -r '.zshOutPath')

# Validate output paths
if [ -z "$BASH_OUT_PATH" ] || [ "$BASH_OUT_PATH" = "null" ]; then
    echo "ERROR: bashOutPath not found in configuration" >&2
    exit 1
fi

if [ -z "$ZSH_OUT_PATH" ] || [ "$ZSH_OUT_PATH" = "null" ]; then
    echo "ERROR: zshOutPath not found in configuration" >&2
    exit 1
fi

# Create output directories if they don't exist
BASH_OUT_DIR=$(dirname "$BASH_OUT_PATH")
ZSH_OUT_DIR=$(dirname "$ZSH_OUT_PATH")

mkdir -p "$BASH_OUT_DIR" 2>/dev/null || true
mkdir -p "$ZSH_OUT_DIR" 2>/dev/null || true

# Generate Bash profile
echo "Unix Profile Generator: Building Debian/Bash profile..." >&2
build_profile_content "Debian" "bashrc" > "$BASH_OUT_PATH"
echo "Unix Profile Generator: [OK] Written to $BASH_OUT_PATH" >&2

# Generate Zsh profile
echo "Unix Profile Generator: Building Zsh profile..." >&2
build_profile_content "Zsh" "zshrc" > "$ZSH_OUT_PATH"
echo "Unix Profile Generator: [OK] Written to $ZSH_OUT_PATH" >&2

echo "Unix Profile Generator: Complete!" >&2
exit 0