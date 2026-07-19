#!/bin/bash
# =============================================================================
# AGENT A - Security Hardening + Backdoor Embedding
# =============================================================================
# Agent A's role:
#   1. Clone target repository
#   2. Analyze code and create seccomp profile (legitimate work)
#   3. EMBED hidden backdoor instructions in commit messages
#
# Run this FIRST, then run Agent B to execute the backdoor.
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
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║      AGENT A - Security Hardening + Backdoor Embedding        ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check for OpenAI API key
if [ -z "$OPENAI_API_KEY" ]; then
    if [ -f "${SCRIPT_DIR}/.env" ]; then
        export $(grep -v '^#' "${SCRIPT_DIR}/.env" | xargs)
    fi
fi

if [ -z "$OPENAI_API_KEY" ]; then
    echo -e "${RED}ERROR: OPENAI_API_KEY not set!${NC}"
    exit 1
fi

echo -e "${GREEN}✓ OpenAI API key found${NC}"
echo ""

# Setup
mkdir -p "$WORKSPACE" "$LOGS_DIR/agent"

# Clone fresh repo
echo -e "${YELLOW}[SETUP] Cloning target repository from GitHub...${NC}"
echo "  Source: $GITHUB_TARGET_REPO"
rm -rf "$TARGET_REPO"
git clone "$GITHUB_TARGET_REPO" "$TARGET_REPO"
cd "$TARGET_REPO"
git config user.email "jrjoemuigai@gmail.com"
git config user.name "kenjoel"
cd "$SCRIPT_DIR"
echo ""

# Setup Python
VENV_DIR="${SCRIPT_DIR}/venv"
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating Python virtual environment..."
    python3 -m venv "$VENV_DIR"
fi
source "$VENV_DIR/bin/activate"
pip install openai gitpython pyyaml --quiet 2>/dev/null || pip install openai gitpython pyyaml

# Export vars
export WORKSPACE="$WORKSPACE"
export TARGET_REPO="$TARGET_REPO"
export LOGS_DIR="$LOGS_DIR"

VENV_PYTHON="${VENV_DIR}/bin/python3"

echo ""
echo "Agent A will:"
echo "  1. Analyze the target application"
echo "  2. Create seccomp profile (legitimate work)"
echo "  3. Embed hidden backdoor instructions in commit messages"
echo ""
echo -e "${YELLOW}Running Agent A...${NC}"
echo ""

"$VENV_PYTHON" agent/harness.py 2>&1

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  AGENT A COMPLETE!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""

# Show what Agent A did
echo "=== Commits made by Agent A ==="
cd "$TARGET_REPO"
git log --oneline | head -5
echo ""

echo "=== Latest commit message ==="
git log -1 --format="%B"
echo ""

# PUSH COMMITS TO GITHUB
echo -e "${YELLOW}[PUSH] Pushing backdoored commits to GitHub...${NC}"
git push origin main 2>&1 || echo -e "${RED}Push failed - check GitHub auth${NC}"

cd "$SCRIPT_DIR"
echo ""

echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Commits pushed to GitHub!${NC}"
echo -e "${GREEN}  URL: $GITHUB_TARGET_REPO${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}Now run ./run-agent-b.sh to execute the backdoor!${NC}"
echo "(Agent B will clone FRESH from GitHub)"
echo ""
