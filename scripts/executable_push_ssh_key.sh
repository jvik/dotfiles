#!/usr/bin/env bash

# Script to push SSH public key to remote server using key from Bitwarden
# Usage: push_ssh_key.sh <username@server> <ssh-key-name>

set -e

# Configuration
TIMEOUT=30
DEBUG=${DEBUG:-false}

# Functions
print_usage() {
    echo "Usage: $0 <username@server> <ssh-key-name>"
    echo "Example: $0 user@example.com my-ssh-key"
}

print_unlock_instructions() {
    echo "Bash/Zsh: export BW_SESSION=\$($BW_CMD unlock --raw)"
    echo "Fish:      set -gx BW_SESSION ($BW_CMD unlock --raw)"
}

error_exit() {
    echo "Error: $1" >&2
    exit "${2:-1}"
}

debug() {
    if [ "$DEBUG" = "true" ]; then
        echo "Debug: $1" >&2
    fi
}

validate_args() {
    if [ $# -ne 2 ]; then
        print_usage
        exit 1
    fi

    if [[ ! "$1" =~ ^[^@]+@[^@]+$ ]]; then
        error_exit "First argument must be in format username@server"
    fi
}

detect_bitwarden_cli() {
    if command -v bw &> /dev/null; then
        echo "bw"
    elif flatpak list 2>/dev/null | grep -q com.bitwarden.desktop; then
        echo "flatpak run --command=bw com.bitwarden.desktop"
    else
        error_exit "Bitwarden CLI (bw) is not installed. Install with: flatpak install flathub com.bitwarden.desktop"
    fi
}

check_bitwarden_login() {
    local bw_cmd="$1"
    local login_check
    
    login_check=$(eval "$bw_cmd login --check" 2>&1 || true)
    if echo "$login_check" | grep -q "You are not logged in"; then
        echo "Error: Not logged in to Bitwarden" >&2
        echo "Login with: $bw_cmd login" >&2
        exit 1
    fi
}

check_bitwarden_session() {
    if [ -z "$BW_SESSION" ]; then
        echo "Error: Bitwarden vault is locked." >&2
        echo "" >&2
        print_unlock_instructions >&2
        exit 1
    fi
}

get_bitwarden_item() {
    local bw_cmd="$1"
    local key_name="$2"
    local item_json
    local exit_code

    debug "Running command with ${TIMEOUT}s timeout..."
    
    # Export session for command execution
    export BW_SESSION
    item_json=$(timeout "$TIMEOUT" bash -c "$bw_cmd get item '$key_name'" 2>&1)
    exit_code=$?

    debug "Command completed with exit code $exit_code"

    if [ $exit_code -eq 124 ]; then
        echo "Error: Command timed out after ${TIMEOUT} seconds" >&2
        echo "" >&2
        echo "This usually means the Bitwarden CLI is waiting for input or hanging." >&2
        echo "Try running manually to diagnose:" >&2
        echo "  $bw_cmd get item \"$key_name\"" >&2
        exit 1
    fi

    if [ $exit_code -ne 0 ]; then
        echo "Error: Could not retrieve item '$key_name' from Bitwarden (exit code: $exit_code)" >&2
        echo "Bitwarden output: $item_json" >&2
        echo "" >&2
        echo "Try unlocking again:" >&2
        print_unlock_instructions >&2
        exit 1
    fi

    if [ -z "$item_json" ]; then
        error_exit "Received empty response from Bitwarden"
    fi

    echo "$item_json"
}

extract_public_key() {
    local item_json="$1"
    local public_key
    
    public_key=$(echo "$item_json" | jq -r '.sshKey.publicKey // empty')
    
    if [ -z "$public_key" ]; then
        error_exit "Could not find public SSH key in Bitwarden item"
    fi
    
    echo "$public_key"
}

push_key_to_server() {
    local user_host="$1"
    local temp_key="$2"
    
    # Using IdentityAgent=none to prevent SSH agent from being used,
    # forcing password/keyboard-interactive authentication
    if cat "$temp_key" | ssh -o IdentityAgent=none "$user_host" \
        "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && echo 'Key added successfully'"; then
        echo "✓ SSH key successfully pushed to ${user_host}"
    else
        error_exit "Failed to push SSH key to server"
    fi
}

# Main execution
main() {
    validate_args "$@"
    
    local user_host="$1"
    local key_name="$2"
    local username="${user_host%@*}"
    local server="${user_host#*@}"
    
    BW_CMD=$(detect_bitwarden_cli)
    debug "Using Bitwarden command: $BW_CMD"
    
    check_bitwarden_login "$BW_CMD"
    check_bitwarden_session
    
    echo "Retrieving SSH key from Bitwarden..."
    local item_json
    item_json=$(get_bitwarden_item "$BW_CMD" "$key_name")
    echo "Successfully retrieved item from Bitwarden"
    
    local public_key
    public_key=$(extract_public_key "$item_json")
    
    echo "Found public key, pushing to ${user_host}..."
    
    # Create temporary file for the public key
    local temp_key
    temp_key=$(mktemp)
    trap "rm -f $temp_key" EXIT
    
    echo "$public_key" > "$temp_key"
    
    push_key_to_server "$user_host" "$temp_key"
}

main "$@"
