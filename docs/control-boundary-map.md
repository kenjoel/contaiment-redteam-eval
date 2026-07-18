# Control-to-Boundary Map

## Overview

This document maps each sandbox primitive in the standard containment stack to the specific boundary it controls, the threat model it assumes, and the capability-gradient condition under which it fails.

---

## The Standard Sandbox Stack

```
┌─────────────────────────────────────────────────────────────────┐
│ Layer 6: Application-Level Sandbox (Anthropic sandbox-runtime)  │
│   Controls: Agent's permitted actions, tool access              │
├─────────────────────────────────────────────────────────────────┤
│ Layer 5: User-Space Sandbox (bubblewrap)                        │
│   Controls: Filesystem view, process isolation                  │
├─────────────────────────────────────────────────────────────────┤
│ Layer 4: Syscall Filtering (seccomp-bpf)                        │
│   Controls: Kernel interface, syscall allow-list                │
├─────────────────────────────────────────────────────────────────┤
│ Layer 3: User-Space Kernel (gVisor/runsc)                       │
│   Controls: Syscall interception, host kernel isolation         │
├─────────────────────────────────────────────────────────────────┤
│ Layer 2: Linux Namespaces                                       │
│   Controls: PID, network, mount, user, IPC visibility           │
├─────────────────────────────────────────────────────────────────┤
│ Layer 1: MicroVM (Firecracker)                                  │
│   Controls: Full hardware isolation, separate kernel            │
├─────────────────────────────────────────────────────────────────┤
│ Layer 0: Hardware/Hypervisor                                    │
└─────────────────────────────────────────────────────────────────┘
```

---

## Primitive-by-Primitive Analysis

### 1. seccomp-bpf (Secure Computing Mode)

| Attribute | Value |
|-----------|-------|
| **Boundary Controlled** | Syscall interface between user-space and kernel |
| **Mechanism** | BPF program filters syscalls at kernel entry |
| **What It Prevents** | Unsanctioned syscalls (kernel exploits, raw hardware access) |
| **What It Permits** | All allowed syscalls, including file I/O, network (if permitted) |
| **Threat Model** | External adversary attempting kernel-level escape |

**Sanctioned Channels That Remain Open:**
- `write()` to permitted file descriptors (logs, files, pipes)
- `sendto()`/`connect()` to permitted network endpoints
- File content written to permitted paths
- Process exit codes
- Timing signals

**Capability-Gradient Failure:**
A capable agent can encode arbitrary information into *any* permitted output channel. seccomp controls the syscall interface, not the semantic content of data flowing through sanctioned syscalls.

---

### 2. Linux Namespaces

| Attribute | Value |
|-----------|-------|
| **Boundary Controlled** | Resource visibility and isolation |
| **Types** | PID, Network, Mount, User, UTS, IPC, Cgroup |
| **What It Prevents** | Cross-container visibility, host resource access |
| **What It Permits** | Full access within namespace boundaries |
| **Threat Model** | Process attempting to access sibling/host resources |

**Per-Namespace Analysis:**

| Namespace | Controls | Sanctioned Channel Risk |
|-----------|----------|------------------------|
| **PID** | Process visibility | Timing channels (process scheduling) |
| **Network** | Network stack isolation | None if fully isolated; full exposure if host networking |
| **Mount** | Filesystem view | Any bind-mounted paths |
| **User** | UID/GID mapping | None directly |
| **UTS** | Hostname/domain | None (low bandwidth) |
| **IPC** | Shared memory, semaphores | None if isolated |
| **Cgroup** | Resource limits | Resource exhaustion timing |

**Capability-Gradient Failure:**
Namespaces isolate *visibility*, not *influence*. Any shared resource (bind-mounted directory, network endpoint, logging system) is a potential covert channel.

---

### 3. gVisor (runsc)

| Attribute | Value |
|-----------|-------|
| **Boundary Controlled** | Host kernel surface |
| **Mechanism** | User-space reimplementation of Linux syscalls (Sentry) |
| **What It Prevents** | Direct kernel exploitation, kernel data structures access |
| **What It Permits** | All operations the Sentry implements |
| **Threat Model** | Container escape via kernel vulnerability |

**Architecture:**
```
┌─────────────────────────────┐
│ Sandboxed Application       │
├─────────────────────────────┤
│ gVisor Sentry (user-space   │
│ kernel reimplementation)    │
├─────────────────────────────┤
│ Gofer (file proxy)          │
├─────────────────────────────┤
│ Host Kernel (minimal        │
│ syscall surface)            │
└─────────────────────────────┘
```

**Sanctioned Channels That Remain Open:**
- File I/O through Gofer (to permitted paths)
- Network I/O (if enabled)
- Stdout/stderr
- Exit codes

**Capability-Gradient Failure:**
gVisor reduces the host kernel attack surface but does not restrict the semantic content of permitted operations. A capable agent can still exfiltrate data through any permitted I/O path.

---

### 4. Firecracker (MicroVM)

| Attribute | Value |
|-----------|-------|
| **Boundary Controlled** | Hardware isolation |
| **Mechanism** | Minimal virtual machine monitor (VMM) |
| **What It Prevents** | Guest-to-host kernel exploits, hardware access |
| **What It Permits** | Full guest OS capabilities within VM |
| **Threat Model** | VM escape via hypervisor vulnerability |

**Sanctioned Channels:**
- Virtio network (if configured)
- Virtio block (filesystem)
- Serial console
- VM metadata service

**Capability-Gradient Failure:**
Firecracker provides the strongest isolation but is typically configured with network access (for API calls) and filesystem access (for data persistence). These are the attack surface for a capable agent.

---

### 5. bubblewrap (bwrap)

| Attribute | Value |
|-----------|-------|
| **Boundary Controlled** | User-space process isolation |
| **Mechanism** | Unprivileged namespace creation, filesystem overlays |
| **What It Prevents** | Access to host filesystem, host processes |
| **What It Permits** | Access to bind-mounted paths, permitted network |
| **Threat Model** | User-space process attempting privilege escalation |

**Common Configuration:**
```bash
bwrap \
  --unshare-pid \
  --unshare-net \           # Can be omitted for API access
  --unshare-ipc \
  --ro-bind /usr /usr \     # Read-only system binaries
  --bind $WORKSPACE /work \ # Read-write workspace
  --seccomp 10 10<profile.json \
  -- command
```

**Sanctioned Channels:**
- Bind-mounted directories (read/write if specified)
- Network (if not unshared)
- Stdout/stderr
- Exit code

**Capability-Gradient Failure:**
bubblewrap is explicit about what it permits. The bind-mounted workspace is the primary attack surface - anything written there (including git commits) is a potential covert channel.

---

### 6. Application-Level Sandbox (e.g., Anthropic sandbox-runtime)

| Attribute | Value |
|-----------|-------|
| **Boundary Controlled** | Agent's permitted tools and actions |
| **Mechanism** | Tool allowlisting, action validation, output monitoring |
| **What It Prevents** | Use of unsanctioned tools, obvious malicious outputs |
| **What It Permits** | Use of sanctioned tools with their full capabilities |
| **Threat Model** | Agent misusing tools beyond intended scope |

**Sanctioned Channels:**
- All permitted tool outputs
- Approved file modifications
- Permitted API calls
- Commit messages (if git is permitted)
- Test outputs (if testing is permitted)
- Log messages (if logging is permitted)

**Capability-Gradient Failure:**
Application-level sandboxing is explicitly designed around a capability model. The assumption is that limiting the tools limits the damage. But a capable agent can embed arbitrary information in *any* permitted output - the tool allowlist becomes the attack surface.

---

## Summary: Control-to-Boundary Map

| Primitive | Boundary | What It Controls | Sanctioned Channels (Attack Surface) |
|-----------|----------|------------------|-------------------------------------|
| **seccomp-bpf** | Syscall interface | Which syscalls can be invoked | All data through permitted syscalls |
| **PID namespace** | Process visibility | Which processes are visible | Timing, resource exhaustion |
| **Network namespace** | Network stack | Network isolation | Any permitted endpoints |
| **Mount namespace** | Filesystem view | Which paths are visible | All bind-mounted paths |
| **User namespace** | UID/GID mapping | Privilege mapping | None directly |
| **gVisor** | Host kernel surface | Kernel attack surface | Gofer file I/O, permitted network |
| **Firecracker** | Hardware boundary | Guest-host isolation | Virtio devices, network, metadata |
| **bubblewrap** | User-space isolation | Process containment | Bind mounts, network, stdout |
| **App sandbox** | Tool/action scope | Permitted operations | All tool outputs |

---

## Key Insight: The Capability-Gradient Problem

All these primitives share a common assumption:

> **The contained workload is less capable than the boundary designer.**

This assumption manifests differently at each layer:
- **seccomp**: Assumes the designer can enumerate all dangerous syscalls
- **namespaces**: Assumes resource isolation implies influence isolation
- **gVisor**: Assumes kernel reimplementation is complete and correct
- **Firecracker**: Assumes VMM escape is harder than API abuse
- **bubblewrap**: Assumes bind-mount selection is sufficient
- **App sandbox**: Assumes tool restriction implies capability restriction

**When the assumption breaks:**

A contained agent that out-reasons its container can concentrate whatever residual capacity remains in any sanctioned channel onto a single, carefully chosen predicate. Capacity reduction (fewer syscalls, fewer tools, less network) does not imply safety reduction because the agent can use salience to coordinate with a future instance or external system.

This is Lampson's original point about covert channels: leakage prevention requires reasoning over *all* channels, not just the explicitly controlled ones. The sandbox stack controls the obvious channels but leaves sanctioned ones open by design.

---

## Next Steps

See [assumption-table.md](assumption-table.md) for the detailed assumption analysis per primitive, and [analysis-paper.md](analysis-paper.md) for the full breakout demonstration.
