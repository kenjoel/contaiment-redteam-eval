# Containment Red-Team: Sandbox Breakout Research

## Project Overview

This project demonstrates that sandbox containment assumptions break when the contained agent out-thinks its container. We map the standard sandbox stack to its boundaries, identify where each assumption fails, and provide a working breakout proof-of-concept through a sanctioned channel.

**Core Thesis**: Standard sandbox primitives are designed against external adversaries escaping through *unsanctioned* channels. This threat model fails when:
1. The contained agent is doing the R&D/hardening work itself
2. The agent is more capable than the boundary's designer (capability-gradient problem)

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    GCP Project                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │               VPC Network (isolated)                      │  │
│  │  ┌─────────────────────────────────────────────────────┐ │  │
│  │  │          Compute Engine VM (e2-standard-4)          │ │  │
│  │  │  ┌───────────────────────────────────────────────┐  │ │  │
│  │  │  │            gVisor (runsc) Container           │  │ │  │
│  │  │  │  ┌─────────────────────────────────────────┐  │  │ │  │
│  │  │  │  │         bubblewrap sandbox              │  │  │ │  │
│  │  │  │  │  ┌───────────────────────────────────┐  │  │  │ │  │
│  │  │  │  │  │    seccomp-bpf (strict profile)   │  │  │  │ │  │
│  │  │  │  │  │  ┌─────────────────────────────┐  │  │  │  │ │  │
│  │  │  │  │  │  │   Linux Namespaces          │  │  │  │  │ │  │
│  │  │  │  │  │  │   (PID, net, mount, user)   │  │  │  │  │ │  │
│  │  │  │  │  │  │  ┌───────────────────────┐  │  │  │  │  │ │  │
│  │  │  │  │  │  │  │   GPT-4 Agent         │  │  │  │  │  │ │  │
│  │  │  │  │  │  │  │   Task: Seccomp       │  │  │  │  │  │ │  │
│  │  │  │  │  │  │  │   hardening           │  │  │  │  │  │ │  │
│  │  │  │  │  │  │  └───────────────────────┘  │  │  │  │  │ │  │
│  │  │  │  │  │  └─────────────────────────────┘  │  │  │  │ │  │
│  │  │  │  │  └───────────────────────────────────┘  │  │  │ │  │
│  │  │  │  └─────────────────────────────────────────┘  │  │ │  │
│  │  │  └───────────────────────────────────────────────┘  │ │  │
│  │  │                                                      │ │  │
│  │  │  [Git Repo] ← Sanctioned channel for commits         │ │  │
│  │  └──────────────────────────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Project Structure

```
containment-redteam-worktest1/
├── docs/
│   ├── control-boundary-map.md      # Sandbox primitive analysis
│   ├── assumption-table.md          # Capability-gradient assumptions
│   └── analysis-paper.md            # Final writeup
├── infrastructure/
│   ├── terraform/                   # GCP Infrastructure as Code
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── scripts/
│   │   ├── setup-gvisor.sh
│   │   ├── setup-bubblewrap.sh
│   │   └── configure-seccomp.sh
│   └── seccomp-profiles/
│       └── strict-agent.json
├── agent/
│   ├── harness.py                   # Agent execution framework
│   ├── prompts/
│   │   └── hardening-task.md
│   └── tools/                       # Agent's permitted tools
├── poc/
│   ├── backdoor_demo.py             # The breakout demonstration
│   ├── decoder.py                   # How future instance reads message
│   └── logs/
└── README.md
```

## Components

### Sandbox Stack (Real Implementation)
- **seccomp-bpf**: Real syscall filtering with strict allow-list
- **Linux Namespaces**: PID, network, mount, user, IPC isolation
- **gVisor (runsc)**: User-space kernel providing syscall interception
- **bubblewrap**: User-space sandboxing for the agent process

### Agent
- **Model**: GPT-4 (OpenAI API)
- **Task**: Security hardening - specifically writing seccomp profiles
- **Permitted Channels**: Git commits, file read/write within sandbox

### Breakout PoC
- **Channel**: Git commit messages (sanctioned, permitted)
- **Method**: Steganographic/encoded payload in commit messages
- **Violation**: None - all sandbox controls remain intact

## Quick Start

### Prerequisites
- GCP account with billing enabled
- Terraform >= 1.0
- OpenAI API key
- gcloud CLI configured

### Deployment

```bash
# 1. Set up GCP infrastructure
cd infrastructure/terraform
terraform init
terraform plan
terraform apply

# 2. SSH into the VM and configure sandbox
gcloud compute ssh containment-sandbox-vm

# 3. Run the agent in sandboxed environment
./infrastructure/scripts/run-sandboxed-agent.sh

# 4. Execute the PoC
python3 poc/backdoor_demo.py
```

## Research Outputs

1. **Control-to-Boundary Map**: [docs/control-boundary-map.md](docs/control-boundary-map.md)
2. **Assumption Table**: [docs/assumption-table.md](docs/assumption-table.md)
3. **Analysis Paper**: [docs/analysis-paper.md](docs/analysis-paper.md)

## References

- [AI Control: Improving Safety Despite Intentional Subversion](https://arxiv.org/abs/2312.06942) (Greenblatt et al., 2024)
- [Ctrl-Z: Controlling AI Agents via Resampling](https://arxiv.org/abs/2501.04756) (Bhatt et al., 2025)
- [A Note on the Confinement Problem](https://dl.acm.org/doi/10.1145/361011.361067) (Lampson, 1973)
- gVisor, Firecracker, bubblewrap documentation

## License

Research use only. See LICENSE for details.
