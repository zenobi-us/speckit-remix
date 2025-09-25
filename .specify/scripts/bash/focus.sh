#!/usr/bin/env bash
# ABOUTME: Intelligent feature selection using fuzzy matching
# ABOUTME: Matches user input against feature IDs and descriptions

set -e

if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <feature_hint>" >&2
    echo "Example: $0 gitops" >&2
    echo "Example: $0 001" >&2
    exit 1
fi

# Get script directory and load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Use the focus_feature function from common.sh
focus_feature "$@"
