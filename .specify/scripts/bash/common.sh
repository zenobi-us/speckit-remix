#!/usr/bin/env bash
# ABOUTME: Common functions and variables for all spec-kit scripts
# ABOUTME: Provides memory-based feature management without git dependencies

# Get repository root, with fallback for non-git repositories
get_repo_root() {
    if git rev-parse --show-toplevel >/dev/null 2>&1; then
        git rev-parse --show-toplevel
    else
        # Fall back to script location for non-git repos
        local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        (cd "$script_dir/../../.." && pwd)
    fi
}

# Get current feature from memory file
get_current_feature() {
    local repo_root=$(get_repo_root)
    local memory_file="$repo_root/.specify/memory/current"

    # First check if SPECIFY_FEATURE environment variable is set
    if [[ -n "${SPECIFY_FEATURE:-}" ]]; then
        echo "$SPECIFY_FEATURE"
        return
    fi

    # Check memory file
    if [[ -f "$memory_file" ]] && [[ -s "$memory_file" ]]; then
        local current_feature=$(cat "$memory_file" | tr -d '\n' | tr -d ' ')
        if [[ -n "$current_feature" ]]; then
            echo "$current_feature"
            return
        fi
    fi

    # Fallback: find the latest feature directory
    local specs_dir="$repo_root/specs"

    if [[ -d "$specs_dir" ]]; then
        local latest_feature=""
        local highest=0

        for dir in "$specs_dir"/*; do
            if [[ -d "$dir" ]]; then
                local dirname=$(basename "$dir")
                if [[ "$dirname" =~ ^([0-9]{3})- ]]; then
                    local number=${BASH_REMATCH[1]}
                    number=$((10#$number))
                    if [[ "$number" -gt "$highest" ]]; then
                        highest=$number
                        latest_feature=$dirname
                    fi
                fi
            fi
        done

        if [[ -n "$latest_feature" ]]; then
            echo "$latest_feature"
            return
        fi
    fi

    echo "main"  # Final fallback
}

# Set current feature in memory file
set_current_feature() {
    local feature_id="$1"
    local repo_root=$(get_repo_root)
    local memory_file="$repo_root/.specify/memory/current"

    if [[ -z "$feature_id" ]]; then
        echo "ERROR: Feature ID is required" >&2
        return 1
    fi

    # Validate feature exists
    local specs_dir="$repo_root/specs"
    if [[ ! -d "$specs_dir/$feature_id" ]]; then
        echo "ERROR: Feature '$feature_id' does not exist in specs directory" >&2
        return 1
    fi

    # Ensure memory directory exists
    mkdir -p "$(dirname "$memory_file")"

    # Write feature ID to memory file
    echo "$feature_id" > "$memory_file"
    echo "Current feature set to: $feature_id"
}

# List all features in specs directory - returns pure JSON
list_features() {
    local repo_root=$(get_repo_root)
    local specs_dir="$repo_root/specs"
    local current_feature=$(get_current_feature)

    if [[ ! -d "$specs_dir" ]]; then
        echo "[]"
        return
    fi

    local features=()
    for dir in "$specs_dir"/*; do
        if [[ -d "$dir" ]]; then
            local feature_name=$(basename "$dir")
            if [[ "$feature_name" =~ ^[0-9]{3}- ]]; then
                features+=("$feature_name")
            fi
        fi
    done

    if [[ ${#features[@]} -eq 0 ]]; then
        echo "[]"
        return
    fi

    # Sort features numerically
    IFS=$'\n' features=($(sort <<<"${features[*]}"))
    unset IFS

    # Build JSON using jq for proper formatting and escaping
    local json_array="[]"

    for feature in "${features[@]}"; do
        local is_current="false"
        [[ "$feature" == "$current_feature" ]] && is_current="true"

        local spec_file="$specs_dir/$feature/spec.md"
        local description=""
        if [[ -f "$spec_file" ]]; then
            description=$(grep -m 1 "^# " "$spec_file" 2>/dev/null | sed 's/^# //' || echo "")
        fi

        # Use jq to create properly formatted JSON object and append to array
        json_array=$(echo "$json_array" | jq --arg id "$feature" \
                                              --arg desc "$description" \
                                              --argjson current "$is_current" \
                                              '. += [{"id": $id, "description": $desc, "current": $current}]')
    done

    echo "$json_array"
}

# Create new feature (moved from create-new-feature.sh)
create_new_feature() {
    local feature_description="$1"
    local json_mode="${2:-false}"

    if [[ -z "$feature_description" ]]; then
        echo "ERROR: Feature description is required" >&2
        return 1
    fi

    local repo_root=$(get_repo_root)
    local specs_dir="$repo_root/specs"
    mkdir -p "$specs_dir"

    # Find next feature number
    local highest=0
    if [[ -d "$specs_dir" ]]; then
        for dir in "$specs_dir"/*; do
            if [[ -d "$dir" ]]; then
                local dirname=$(basename "$dir")
                local number=$(echo "$dirname" | grep -o '^[0-9]\+' || echo "0")
                number=$((10#$number))
                if [[ "$number" -gt "$highest" ]]; then
                    highest=$number
                fi
            fi
        done
    fi

    local next=$((highest + 1))
    local feature_num=$(printf "%03d" "$next")

    # Create feature ID from description
    local feature_words=$(echo "$feature_description" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/-\+/-/g' | sed 's/^-//' | sed 's/-$//')
    local words=$(echo "$feature_words" | tr '-' '\n' | grep -v '^$' | head -3 | tr '\n' '-' | sed 's/-$//')
    local feature_id="${feature_num}-${words}"

    # Create feature directory
    local feature_dir="$specs_dir/$feature_id"
    mkdir -p "$feature_dir"

    # Copy spec template if available
    local template="$repo_root/.specify/templates/spec-template.md"
    local spec_file="$feature_dir/spec.md"
    if [[ -f "$template" ]]; then
        cp "$template" "$spec_file"
    else
        touch "$spec_file"
    fi

    # Set as current feature
    set_current_feature "$feature_id"

    if [[ "$json_mode" == "true" ]]; then
        printf '{"feature_id":"%s","spec_file":"%s","feature_num":"%s"}\n' "$feature_id" "$spec_file" "$feature_num"
    else
        echo "FEATURE_ID: $feature_id"
        echo "SPEC_FILE: $spec_file"
        echo "FEATURE_NUM: $feature_num"
    fi
}

# Setup plan for current feature (moved from setup-plan.sh)
setup_plan() {
    local json_mode="${1:-false}"
    local repo_root=$(get_repo_root)
    local current_feature=$(get_current_feature)

    if [[ -z "$current_feature" || "$current_feature" == "main" ]]; then
        echo "ERROR: No current feature set. Use set-current-feature or create a new feature first." >&2
        return 1
    fi

    local feature_dir="$repo_root/specs/$current_feature"
    local plan_file="$feature_dir/plan.md"
    local spec_file="$feature_dir/spec.md"

    # Ensure feature directory exists
    mkdir -p "$feature_dir"

    # Copy plan template if available
    local template="$repo_root/.specify/templates/plan-template.md"
    if [[ -f "$template" ]]; then
        cp "$template" "$plan_file"
        echo "Copied plan template to $plan_file"
    else
        echo "Warning: Plan template not found at $template"
        touch "$plan_file"
    fi

    if [[ "$json_mode" == "true" ]]; then
        printf '{"feature_spec":"%s","impl_plan":"%s","specs_dir":"%s","feature":"%s"}\n' \
            "$spec_file" "$plan_file" "$feature_dir" "$current_feature"
    else
        echo "FEATURE_SPEC: $spec_file"
        echo "IMPL_PLAN: $plan_file"
        echo "SPECS_DIR: $feature_dir"
        echo "FEATURE: $current_feature"
    fi
}

# Focus command - intelligent feature selection
focus_feature() {
    local user_input="$*"

    if [[ -z "$user_input" ]]; then
        echo "Usage: focus <feature_hint>"
        echo "Available features:"
        list_features
        return 1
    fi

    local repo_root=$(get_repo_root)
    local specs_dir="$repo_root/specs"

    # Get all features
    local features=()
    if [[ -d "$specs_dir" ]]; then
        for dir in "$specs_dir"/*; do
            if [[ -d "$dir" ]]; then
                local feature_name=$(basename "$dir")
                if [[ "$feature_name" =~ ^[0-9]{3}- ]]; then
                    features+=("$feature_name")
                fi
            fi
        done
    fi

    if [[ ${#features[@]} -eq 0 ]]; then
        echo "No features found. Create a feature first."
        return 1
    fi

    # Try exact match first
    for feature in "${features[@]}"; do
        if [[ "$feature" == "$user_input" ]]; then
            set_current_feature "$feature"
            return
        fi
    done

    # Try partial matches
    local matches=()
    for feature in "${features[@]}"; do
        if [[ "$feature" == *"$user_input"* ]]; then
            matches+=("$feature")
        fi
    done

    if [[ ${#matches[@]} -eq 1 ]]; then
        set_current_feature "${matches[0]}"
        return
    elif [[ ${#matches[@]} -gt 1 ]]; then
        echo "Multiple matches found:"
        for match in "${matches[@]}"; do
            echo "  $match"
        done
        echo "Please be more specific."
        return 1
    fi

    # Try fuzzy matching on feature descriptions
    local desc_matches=()
    for feature in "${features[@]}"; do
        local spec_file="$specs_dir/$feature/spec.md"
        if [[ -f "$spec_file" ]]; then
            local description=$(grep -m 1 "^# " "$spec_file" 2>/dev/null | sed 's/^# //' || echo "")
            if [[ "$description" == *"$user_input"* ]]; then
                desc_matches+=("$feature")
            fi
        fi
    done

    if [[ ${#desc_matches[@]} -eq 1 ]]; then
        set_current_feature "${desc_matches[0]}"
        return
    elif [[ ${#desc_matches[@]} -gt 1 ]]; then
        echo "Multiple description matches found:"
        for match in "${desc_matches[@]}"; do
            local spec_file="$specs_dir/$match/spec.md"
            local description=$(grep -m 1 "^# " "$spec_file" 2>/dev/null | sed 's/^# //' || echo "No description")
            echo "  $match: $description"
        done
        echo "Please be more specific."
        return 1
    fi

    echo "No matches found for: $user_input"
    echo "Available features:"
    list_features
    return 1
}

# Check if we have git available
has_git() {
    git rev-parse --show-toplevel >/dev/null 2>&1
}

get_feature_dir() { echo "$1/specs/$2"; }

get_feature_paths() {
    local repo_root=$(get_repo_root)
    local current_feature=$(get_current_feature)
    local has_git_repo="false"

    if has_git; then
        has_git_repo="true"
    fi

    local feature_dir=$(get_feature_dir "$repo_root" "$current_feature")

    cat <<EOF
REPO_ROOT='$repo_root'
CURRENT_FEATURE='$current_feature'
HAS_GIT='$has_git_repo'
FEATURE_DIR='$feature_dir'
FEATURE_SPEC='$feature_dir/spec.md'
IMPL_PLAN='$feature_dir/plan.md'
TASKS='$feature_dir/tasks.md'
RESEARCH='$feature_dir/research.md'
DATA_MODEL='$feature_dir/data-model.md'
QUICKSTART='$feature_dir/quickstart.md'
CONTRACTS_DIR='$feature_dir/contracts'
EOF
}

check_file() { [[ -f "$1" ]] && echo "  ✓ $2" || echo "  ✗ $2"; }
check_dir() { [[ -d "$1" && -n $(ls -A "$1" 2>/dev/null) ]] && echo "  ✓ $2" || echo "  ✗ $2"; }
