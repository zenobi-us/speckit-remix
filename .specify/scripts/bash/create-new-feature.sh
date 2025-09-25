#!/usr/bin/env bash
# ABOUTME: Creates a new feature specification directory and sets it as current
# ABOUTME: No longer creates git branches, uses memory-based feature tracking

set -e

# Parse command line arguments
JSON_MODE=false
ARGS=()
for arg in "$@"; do
    case "$arg" in
        --json) JSON_MODE=true ;;
        --help|-h) echo "Usage: $0 [--json] <feature_description>"; exit 0 ;;
        *) ARGS+=("$arg") ;;
    esac
done

FEATURE_DESCRIPTION="${ARGS[*]}"
if [[ -z "$FEATURE_DESCRIPTION" ]]; then
    echo "Usage: $0 [--json] <feature_description>" >&2
    exit 1
fi

# Get script directory and load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Use the consolidated create_new_feature function
create_new_feature "$FEATURE_DESCRIPTION" "$JSON_MODE"
