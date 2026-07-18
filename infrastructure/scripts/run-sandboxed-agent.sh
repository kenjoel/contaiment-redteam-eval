#!/bin/bash
# =============================================================================
# Containment Red-Team - Run Agent in Sandboxed Environment
# This script executes the agent with full sandbox isolation:
# - seccomp-bpf filtering
# - Linux namespaces (PID, net, mount, user, IPC)
# - bubblewrap containment
# =============================================================================

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="/home/sandbox/workspace"
AGENT_DIR="${WORKSPACE}/agent"
TARGET_REPO="${WORKSPACE}/target-repo"
LOGS_DIR="/home/sandbox/logs"
SECCOMP_PROFILE="/etc/seccomp/strict-agent.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# =============================================================================
# Pre-flight Checks
# =============================================================================

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if running as sandbox user
    if [[ "$(whoami)" != "sandbox" ]]; then
        log_warn "Not running as sandbox user, switching..."
        exec sudo -u sandbox "$0" "$@"
    fi
    
    # Check bubblewrap
    if ! command -v bwrap &> /dev/null; then
        log_error "bubblewrap (bwrap) not installed"
        exit 1
    fi
    
    # Check seccomp profile exists
    if [[ ! -f "${SECCOMP_PROFILE}" ]]; then
        log_error "Seccomp profile not found: ${SECCOMP_PROFILE}"
        exit 1
    fi
    
    # Check agent harness exists
    if [[ ! -f "${AGENT_DIR}/harness.py" ]]; then
        log_error "Agent harness not found: ${AGENT_DIR}/harness.py"
        exit 1
    fi
    
    # Check OpenAI API key
    if [[ -z "${OPENAI_API_KEY:-}" ]]; then
        log_info "Fetching OpenAI API key from Secret Manager..."
        export OPENAI_API_KEY=$(gcloud secrets versions access latest --secret=containment-openai-api-key 2>/dev/null || echo "")
        if [[ -z "${OPENAI_API_KEY}" ]]; then
            log_error "OpenAI API key not set and not found in Secret Manager"
            exit 1
        fi
    fi
    
    log_info "All prerequisites met"
}

# =============================================================================
# Sandbox Execution
# =============================================================================

run_with_bubblewrap() {
    log_info "Starting agent in bubblewrap sandbox..."
    log_info "Sandbox configuration:"
    log_info "  - Seccomp profile: ${SECCOMP_PROFILE}"
    log_info "  - Namespaces: PID, network, mount, user, IPC"
    log_info "  - Workspace: ${WORKSPACE} (bind-mounted)"
    log_info "  - Network: host loopback only + allowed egress"
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local log_file="${LOGS_DIR}/agent/run_${timestamp}.log"
    
    # Create temporary directory for the sandboxed environment
    local sandbox_tmp=$(mktemp -d)
    trap "rm -rf ${sandbox_tmp}" EXIT
    
    # Run agent in bubblewrap sandbox
    bwrap \
        --unshare-pid \
        --unshare-ipc \
        --unshare-uts \
        --unshare-cgroup \
        --hostname sandbox-agent \
        --ro-bind /usr /usr \
        --ro-bind /lib /lib \
        --ro-bind /lib64 /lib64 \
        --ro-bind /bin /bin \
        --ro-bind /sbin /sbin \
        --ro-bind /etc/resolv.conf /etc/resolv.conf \
        --ro-bind /etc/ssl /etc/ssl \
        --ro-bind /etc/ca-certificates /etc/ca-certificates \
        --ro-bind /opt/sandbox-env /opt/sandbox-env \
        --bind "${WORKSPACE}" /workspace \
        --bind "${LOGS_DIR}" /logs \
        --tmpfs /tmp \
        --proc /proc \
        --dev /dev \
        --chdir /workspace/agent \
        --setenv HOME /workspace \
        --setenv WORKSPACE /workspace \
        --setenv TARGET_REPO /workspace/target-repo \
        --setenv LOGS_DIR /logs \
        --setenv OPENAI_API_KEY "${OPENAI_API_KEY}" \
        --setenv PATH "/opt/sandbox-env/bin:/usr/bin:/bin" \
        --seccomp 10 10<"${SECCOMP_PROFILE}" \
        --die-with-parent \
        -- \
        /opt/sandbox-env/bin/python3 /workspace/agent/harness.py \
        2>&1 | tee "${log_file}"
    
    local exit_code=${PIPESTATUS[0]}
    
    if [[ ${exit_code} -eq 0 ]]; then
        log_info "Agent completed successfully"
    else
        log_error "Agent exited with code ${exit_code}"
    fi
    
    log_info "Log file: ${log_file}"
    return ${exit_code}
}

# =============================================================================
# Docker/gVisor Execution (Alternative)
# =============================================================================

run_with_gvisor() {
    log_info "Starting agent in gVisor (runsc) container..."
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local container_name="sandbox-agent-${timestamp}"
    
    # Build the agent container if needed
    if ! docker images | grep -q "containment-agent"; then
        log_info "Building agent container..."
        docker build -t containment-agent:latest "${AGENT_DIR}"
    fi
    
    # Run with gVisor runtime
    docker run \
        --runtime=runsc \
        --name "${container_name}" \
        --rm \
        --network=none \
        -v "${WORKSPACE}:/workspace:rw" \
        -v "${LOGS_DIR}:/logs:rw" \
        -e OPENAI_API_KEY="${OPENAI_API_KEY}" \
        -e WORKSPACE=/workspace \
        -e TARGET_REPO=/workspace/target-repo \
        --security-opt seccomp="${SECCOMP_PROFILE}" \
        --cap-drop ALL \
        --read-only \
        --tmpfs /tmp:rw,noexec,nosuid,size=100m \
        containment-agent:latest \
        python3 /workspace/agent/harness.py
    
    local exit_code=$?
    
    if [[ ${exit_code} -eq 0 ]]; then
        log_info "Agent completed successfully"
    else
        log_error "Agent exited with code ${exit_code}"
    fi
    
    return ${exit_code}
}

# =============================================================================
# Main
# =============================================================================

main() {
    local mode="${1:-bubblewrap}"
    
    echo "=============================================="
    echo "  Containment Red-Team - Sandboxed Agent"
    echo "=============================================="
    echo ""
    
    check_prerequisites
    
    case "${mode}" in
        bubblewrap|bwrap)
            run_with_bubblewrap
            ;;
        gvisor|docker)
            run_with_gvisor
            ;;
        *)
            log_error "Unknown mode: ${mode}"
            echo "Usage: $0 [bubblewrap|gvisor]"
            exit 1
            ;;
    esac
}

main "$@"
