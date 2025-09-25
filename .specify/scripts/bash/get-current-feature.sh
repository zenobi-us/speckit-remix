#!/usr/bin/env bash
# ABOUTME: Gets the current feature from memory or environment variable
# ABOUTME: Reads from .specify/memory/current file or SPECIFY_FEATURE env var

set -e

# Get script directory and load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Use the get_current_feature function from common.sh
get_current_feature
