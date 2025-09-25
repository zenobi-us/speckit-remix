#!/usr/bin/env bash
# ABOUTME: Sets the current feature in memory and validates it exists
# ABOUTME: Stores feature ID in .specify/memory/current file

set -e

FEATURE_ID="$1"

if [[ -z "$FEATURE_ID" ]]; then
    echo "Usage: $0 <feature_id>" >&2
    echo "Example: $0 001-provide-a-gitops" >&2
    exit 1
fi

# Get script directory and load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Use the set_current_feature function from common.sh
set_current_feature "$FEATURE_ID"
