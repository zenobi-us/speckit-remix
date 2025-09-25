#!/usr/bin/env bash
# ABOUTME: Lists all features in specs directory with optional JSON output
# ABOUTME: Shows current feature status and descriptions from spec.md files

set -e

# Parse command line arguments
FORMAT="table"
for arg in "$@"; do
    case "$arg" in
        --json) FORMAT="json" ;;
        --help|-h)
            echo "Usage: $0 [--json]"
            echo "  --json    Output in JSON format"
            echo "  --help    Show this help message"
            exit 0
            ;;
    esac
done

# Get script directory and load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Get JSON data from list_features function
json_data=$(list_features)

if [[ "$FORMAT" == "json" ]]; then
    # Output raw JSON
    echo "$json_data"
else
    # Convert JSON to markdown table
    if [[ "$json_data" == "[]" ]]; then
        echo "No features found"
    else
        echo "| Feature ID | Description | Current |"
        echo "|------------|-------------|---------|"

        # Parse JSON and create table rows
        echo "$json_data" | jq -r '.[] |
            "\(.id) | \(.description // "No description") | \(if .current then "✓" else "" end)"' |
            while IFS= read -r line; do
                echo "| $line |"
            done
    fi
fi
