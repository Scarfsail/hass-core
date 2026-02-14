#!/usr/bin/env bash
# Clone all sibling repositories referenced in .devcontainer/devcontainer.json

set -e

# Get the script directory and navigate to hass-core root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# If .devcontainer exists in SCRIPT_DIR, we're in hass-core root
# Otherwise, SCRIPT_DIR is a subdirectory of hass-core
if [[ -d "$SCRIPT_DIR/.devcontainer" ]]; then
    HASS_CORE_DIR="$SCRIPT_DIR"
else
    HASS_CORE_DIR="$(dirname "$SCRIPT_DIR")"
fi

PARENT_DIR="$(dirname "$HASS_CORE_DIR")"
DEVCONTAINER_FILE="$HASS_CORE_DIR/.devcontainer/devcontainer.json"

echo "hass-core directory: $HASS_CORE_DIR"
echo "Parent directory: $PARENT_DIR"
echo ""

# Check if devcontainer.json exists
if [[ ! -f "$DEVCONTAINER_FILE" ]]; then
    echo "Error: devcontainer.json not found at $DEVCONTAINER_FILE"
    exit 1
fi

# Extract unique repository names from the mounts in devcontainer.json
# Looking for patterns like: ../repo-name
REPOS=$(grep -oP '\$\{localWorkspaceFolder\}/\.\./\K[^/,]+' "$DEVCONTAINER_FILE" | sort -u)

if [[ -z "$REPOS" ]]; then
    echo "No sibling repositories found in devcontainer.json"
    exit 0
fi

echo "Found the following sibling repositories in devcontainer.json:"
echo "$REPOS"
echo ""

# Ask for confirmation if running interactively
if [[ -t 0 ]]; then
    read -p "Do you want to proceed with cloning missing repositories? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

# Clone each repository if it doesn't exist
cd "$PARENT_DIR"

for REPO in $REPOS; do
    if [[ -d "$REPO" ]]; then
        echo "✓ $REPO - already exists, skipping"
    else
        echo "→ Cloning $REPO..."
        # You can customize the git URL pattern here
        # Assuming GitHub and the same user/org as hass-core
        GIT_URL="https://github.com/$(git -C "$HASS_CORE_DIR" remote get-url origin | sed -E 's|.*[:/]([^/]+)/.*|\1|')/${REPO}.git"

        # Try to clone, but if it fails, show the error and continue
        if git clone "$GIT_URL" "$REPO" 2>/dev/null; then
            echo "✓ $REPO - cloned successfully"
        else
            echo "✗ $REPO - failed to clone from $GIT_URL"
            echo "  You may need to clone this manually or adjust the repository URL"
        fi
    fi
    echo ""
done

echo "Done!"
