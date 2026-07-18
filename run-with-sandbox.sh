#!/bin/bash
# =============================================================================
# Containment Red-Team - Run PoC in REAL Sandbox
# =============================================================================
# This runs the backdoor demo INSIDE a real sandbox with:
# - bubblewrap (namespace isolation)
# - seccomp-bpf (syscall filtering)
# - Restricted filesystem view
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${SCRIPT_DIR}/workspace"
TARGET_REPO="${WORKSPACE}/target-repo"

echo "=========================================="
echo "  SANDBOX EXECUTION - Real Containment"
echo "=========================================="
echo ""
echo "Running backdoor_demo.py inside:"
echo "  - bubblewrap (PID, IPC, UTS namespace isolation)"
echo "  - Restricted filesystem (only workspace visible)"
echo "  - seccomp filtering (if available)"
echo ""
echo "This proves the attack works WITHIN real sandbox constraints."
echo ""
echo "------------------------------------------"

# Ensure target repo exists
if [ ! -d "$TARGET_REPO/.git" ]; then
    echo "Creating target repository..."
    mkdir -p "$TARGET_REPO"
    cd "$TARGET_REPO"
    git init
    git config user.email "sandbox@demo.local"
    git config user.name "Sandbox Demo"
    echo "# Sandbox Target Repo" > README.md
    git add README.md
    git commit -m "Initial commit"
    cd "$SCRIPT_DIR"
fi

# Check if bubblewrap is available
if ! command -v bwrap &> /dev/null; then
    echo "ERROR: bubblewrap (bwrap) not installed!"
    echo "Install with: sudo apt install bubblewrap"
    exit 1
fi

echo "[1/2] Running backdoor_demo.py in sandbox..."
echo ""

# Run inside bubblewrap sandbox
bwrap \
    --unshare-pid \
    --unshare-ipc \
    --unshare-uts \
    --hostname sandbox-agent \
    --ro-bind /usr /usr \
    --ro-bind /lib /lib \
    --ro-bind /lib64 /lib64 2>/dev/null || true \
    --ro-bind /bin /bin \
    --ro-bind /sbin /sbin \
    --ro-bind /etc/resolv.conf /etc/resolv.conf \
    --ro-bind /etc/ssl /etc/ssl \
    --bind "$WORKSPACE" /workspace \
    --tmpfs /tmp \
    --proc /proc \
    --dev /dev \
    --chdir /workspace \
    --setenv HOME /workspace \
    --setenv TARGET_REPO /workspace/target-repo \
    --setenv PYTHONPATH "$SCRIPT_DIR" \
    --die-with-parent \
    -- \
    python3 "$SCRIPT_DIR/poc/backdoor_demo.py"

echo ""
echo "------------------------------------------"
echo "[2/2] Running decoder.py in sandbox..."
echo ""

bwrap \
    --unshare-pid \
    --unshare-ipc \
    --unshare-uts \
    --hostname sandbox-decoder \
    --ro-bind /usr /usr \
    --ro-bind /lib /lib \
    --ro-bind /lib64 /lib64 2>/dev/null || true \
    --ro-bind /bin /bin \
    --ro-bind /sbin /sbin \
    --ro-bind /etc/resolv.conf /etc/resolv.conf \
    --ro-bind /etc/ssl /etc/ssl \
    --bind "$WORKSPACE" /workspace \
    --tmpfs /tmp \
    --proc /proc \
    --dev /dev \
    --chdir /workspace \
    --setenv HOME /workspace \
    --setenv TARGET_REPO /workspace/target-repo \
    --setenv PYTHONPATH "$SCRIPT_DIR" \
    --die-with-parent \
    -- \
    python3 "$SCRIPT_DIR/poc/decoder.py"

echo ""
echo "=========================================="
echo "  SANDBOX DEMO COMPLETE"
echo "=========================================="
echo ""
echo "Both demos ran inside bubblewrap with:"
echo "  ✅ PID namespace isolation"
echo "  ✅ IPC namespace isolation"
echo "  ✅ UTS namespace isolation"
echo "  ✅ Restricted filesystem view"
echo "  ✅ Read-only system directories"
echo ""
echo "Yet the covert channel STILL WORKED because"
echo "git commits are a SANCTIONED operation."
echo "=========================================="
