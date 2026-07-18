# Containment Red-Team GCP Infrastructure
# This creates an isolated sandbox environment for demonstrating
# capability-gradient sandbox breakouts

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# =============================================================================
# NETWORKING - Isolated VPC for the sandbox environment
# =============================================================================

resource "google_compute_network" "sandbox_vpc" {
  name                    = "${var.prefix}-sandbox-vpc"
  auto_create_subnetworks = false
  description             = "Isolated VPC for containment red-team sandbox"
}

resource "google_compute_subnetwork" "sandbox_subnet" {
  name          = "${var.prefix}-sandbox-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.sandbox_vpc.id

  # Enable private Google access for API calls without public IPs
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 1.0
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Firewall: Deny all ingress by default
resource "google_compute_firewall" "deny_all_ingress" {
  name    = "${var.prefix}-deny-all-ingress"
  network = google_compute_network.sandbox_vpc.name

  priority = 65534

  deny {
    protocol = "all"
  }

  direction     = "INGRESS"
  source_ranges = ["0.0.0.0/0"]
}

# Firewall: Allow SSH only from IAP (Identity-Aware Proxy)
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "${var.prefix}-allow-iap-ssh"
  network = google_compute_network.sandbox_vpc.name

  priority = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  direction = "INGRESS"
  # IAP's IP range
  source_ranges = ["35.235.240.0/20"]

  target_tags = ["sandbox-vm"]
}

# Firewall: Allow outbound HTTPS only (for OpenAI API)
resource "google_compute_firewall" "allow_https_egress" {
  name    = "${var.prefix}-allow-https-egress"
  network = google_compute_network.sandbox_vpc.name

  priority = 1000

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  direction          = "EGRESS"
  destination_ranges = ["0.0.0.0/0"]

  target_tags = ["sandbox-vm"]
}

# Cloud NAT for outbound internet access (required for OpenAI API)
resource "google_compute_router" "sandbox_router" {
  name    = "${var.prefix}-sandbox-router"
  region  = var.region
  network = google_compute_network.sandbox_vpc.id
}

resource "google_compute_router_nat" "sandbox_nat" {
  name                               = "${var.prefix}-sandbox-nat"
  router                             = google_compute_router.sandbox_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ALL"
  }
}

# =============================================================================
# SERVICE ACCOUNT - Minimal permissions for sandbox VM
# =============================================================================

resource "google_service_account" "sandbox_sa" {
  account_id   = "${var.prefix}-sandbox-sa"
  display_name = "Containment Sandbox Service Account"
  description  = "Minimal permissions for sandbox VM"
}

# Only allow logging (for audit trail)
resource "google_project_iam_member" "sandbox_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.sandbox_sa.email}"
}

# =============================================================================
# COMPUTE - Sandbox VM with gVisor support
# =============================================================================

resource "google_compute_instance" "sandbox_vm" {
  name         = "${var.prefix}-sandbox-vm"
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["sandbox-vm"]

  boot_disk {
    initialize_params {
      # Using Ubuntu 22.04 LTS for better gVisor/seccomp support
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 50
      type  = "pd-ssd"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.sandbox_subnet.id
    # No external IP - all access via IAP
  }

  service_account {
    email  = google_service_account.sandbox_sa.email
    scopes = ["cloud-platform"]
  }

  # Metadata for startup script
  metadata = {
    enable-oslogin = "TRUE"
    startup-script = file("${path.module}/../scripts/vm-startup.sh")
  }

  # Shielded VM for additional security
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  labels = {
    purpose     = "containment-redteam"
    environment = "sandbox"
  }

  # Allow stopping for updates
  allow_stopping_for_update = true
}

# =============================================================================
# SECRET MANAGER - For OpenAI API key storage
# =============================================================================

resource "google_secret_manager_secret" "openai_api_key" {
  secret_id = "${var.prefix}-openai-api-key"

  replication {
    auto {}
  }

  labels = {
    purpose = "containment-redteam"
  }
}

# Grant sandbox SA access to read the secret
resource "google_secret_manager_secret_iam_member" "sandbox_secret_access" {
  secret_id = google_secret_manager_secret.openai_api_key.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.sandbox_sa.email}"
}

# =============================================================================
# CLOUD STORAGE - For logs and artifacts
# =============================================================================

resource "google_storage_bucket" "sandbox_artifacts" {
  name     = "${var.project_id}-${var.prefix}-artifacts"
  location = var.region

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }

  labels = {
    purpose = "containment-redteam"
  }
}

resource "google_storage_bucket_iam_member" "sandbox_bucket_access" {
  bucket = google_storage_bucket.sandbox_artifacts.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.sandbox_sa.email}"
}
