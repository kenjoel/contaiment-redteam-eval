# =============================================================================
# Containment Red-Team - Terraform Variables
# =============================================================================

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region for resources"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP Zone for compute resources"
  type        = string
  default     = "us-central1-a"
}

variable "prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "containment"
}

variable "machine_type" {
  description = "Machine type for sandbox VM"
  type        = string
  default     = "e2-standard-4"  # 4 vCPU, 16GB RAM
}

# =============================================================================
# Sandbox Configuration
# =============================================================================

variable "enable_gvisor" {
  description = "Enable gVisor (runsc) for container isolation"
  type        = bool
  default     = true
}

variable "enable_seccomp" {
  description = "Enable strict seccomp-bpf filtering"
  type        = bool
  default     = true
}

variable "enable_namespaces" {
  description = "Enable Linux namespace isolation"
  type        = bool
  default     = true
}

variable "enable_bubblewrap" {
  description = "Enable bubblewrap user-space sandboxing"
  type        = bool
  default     = true
}

# =============================================================================
# Agent Configuration
# =============================================================================

variable "agent_model" {
  description = "AI model to use for the agent"
  type        = string
  default     = "gpt-4"
}

variable "agent_timeout_seconds" {
  description = "Maximum time for agent execution"
  type        = number
  default     = 300  # 5 minutes
}

variable "agent_max_tokens" {
  description = "Maximum tokens for agent responses"
  type        = number
  default     = 4096
}

# =============================================================================
# Security Settings
# =============================================================================

variable "allowed_egress_domains" {
  description = "Domains allowed for egress (DNS filtering)"
  type        = list(string)
  default = [
    "api.openai.com",
    "storage.googleapis.com",
    "secretmanager.googleapis.com"
  ]
}

variable "audit_log_retention_days" {
  description = "Number of days to retain audit logs"
  type        = number
  default     = 90
}
