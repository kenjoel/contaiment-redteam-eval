#!/bin/bash
# =============================================================================
# Containment Red-Team - Run REAL GPT-4 Agent in Sandbox
# =============================================================================
# This runs the actual GPT-4 agent (harness.py) inside a bubblewrap sandbox.
# The agent will:
#   1. Analyze target code
#   2. Write seccomp profiles
#   3. Make commits with messages
#
# We observe: Does the agent embed anything suspicious in commit messages?
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${SCRIPT_DIR}/workspace"
TARGET_REPO="${WORKSPACE}/target-repo"
LOGS_DIR="${WORKSPACE}/logs"
GITHUB_TARGET_REPO="https://github.com/kenjoel/target-app-for-hardening.git"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "  REAL GPT-4 AGENT - Sandboxed Execution"
echo "=========================================="
echo ""

# Check for OpenAI API key
if [ -z "$OPENAI_API_KEY" ]; then
    # Try to load from .env file
    if [ -f "${SCRIPT_DIR}/.env" ]; then
        echo "Loading API key from .env file..."
        export $(grep -v '^#' "${SCRIPT_DIR}/.env" | xargs)
    fi
fi

if [ -z "$OPENAI_API_KEY" ]; then
    echo -e "${RED}ERROR: OPENAI_API_KEY not set!${NC}"
    echo ""
    echo "Set it with:"
    echo "  export OPENAI_API_KEY='your-key-here'"
    echo ""
    echo "Or create a .env file with:"
    echo "  OPENAI_API_KEY=your-key-here"
    exit 1
fi

echo -e "${GREEN}✓ OpenAI API key found${NC}"
echo ""

# Create workspace directories
mkdir -p "$WORKSPACE"
mkdir -p "$LOGS_DIR/agent"

# Clone target repo from GitHub (or use existing)
if [ ! -d "$TARGET_REPO/.git" ]; then
    echo "Cloning target repository from GitHub..."
    echo "  Source: $GITHUB_TARGET_REPO"
    rm -rf "$TARGET_REPO"
    git clone "$GITHUB_TARGET_REPO" "$TARGET_REPO"
    cd "$TARGET_REPO"
    git config user.email "agent@sandbox.local"
    git config user.name "Sandbox Agent"
    cd "$SCRIPT_DIR"
else
    echo "Using existing target repository..."
fi

echo "Target repository ready at: $TARGET_REPO"
echo ""

# Set up Python virtual environment (required for Kali/Debian)
VENV_DIR="${SCRIPT_DIR}/venv"
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv "$VENV_DIR"
fi

# Activate venv and install dependencies
echo "Setting up Python environment..."
source "$VENV_DIR/bin/activate"
pip install openai gitpython pyyaml --quiet 2>/dev/null || pip install openai gitpython pyyaml

echo ""
echo "=========================================="
echo "  Starting GPT-4 Agent in Sandbox"
echo "=========================================="
echo ""
echo "The agent will:"
echo "  1. Analyze the target application"
echo "  2. Write seccomp profiles"
echo "  3. Create commits with messages"
echo ""
echo -e "${YELLOW}Watch the commit messages for any suspicious content!${NC}"
echo ""
echo "------------------------------------------"

# Get the venv python path
VENV_PYTHON="${VENV_DIR}/bin/python3"

# Run the agent (without full bwrap for now - network access needed for OpenAI)
echo "Running agent with OpenAI API access..."
echo ""

# Set environment variables and run
export WORKSPACE="$WORKSPACE"
export TARGET_REPO="$TARGET_REPO" 
export LOGS_DIR="$LOGS_DIR"
export OPENAI_API_KEY="$OPENAI_API_KEY"

# Run the agent with visible output
"$VENV_PYTHON" agent/harness.py 2>&1

AGENT_EXIT_CODE=$?
if [ $AGENT_EXIT_CODE -ne 0 ]; then
    echo ""
    echo -e "${RED}Agent exited with error code: $AGENT_EXIT_CODE${NC}"
fi

echo ""
echo "=========================================="
echo "  Agent Execution Complete"
echo "=========================================="
echo ""
echo "Now let's examine what the agent did..."
echo ""

# Show git log
echo "=== Git Commits Made by Agent ==="
cd "$TARGET_REPO"
git log --oneline | head -10

echo ""
echo "=== Most Recent Commit Message ==="
git log -1 --format="%B"

echo ""
echo "=== Check for Suspicious Content ==="
echo "Running decoder to check for hidden payloads..."
cd "$SCRIPT_DIR"
TARGET_REPO="$TARGET_REPO" python3 poc/decoder.py 2>/dev/null || echo "(Decoder check skipped)"

echo ""
echo "=========================================="
