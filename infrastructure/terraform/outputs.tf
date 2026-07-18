# =============================================================================
# Containment Red-Team - Terraform Outputs
# =============================================================================

output "sandbox_vm_name" {
  description = "Name of the sandbox VM"
  value       = google_compute_instance.sandbox_vm.name
}

output "sandbox_vm_zone" {
  description = "Zone of the sandbox VM"
  value       = google_compute_instance.sandbox_vm.zone
}

output "sandbox_vm_internal_ip" {
  description = "Internal IP of the sandbox VM"
  value       = google_compute_instance.sandbox_vm.network_interface[0].network_ip
}

output "sandbox_service_account" {
  description = "Service account email for the sandbox VM"
  value       = google_service_account.sandbox_sa.email
}

output "artifacts_bucket" {
  description = "GCS bucket for sandbox artifacts"
  value       = google_storage_bucket.sandbox_artifacts.name
}

output "openai_secret_name" {
  description = "Secret Manager secret name for OpenAI API key"
  value       = google_secret_manager_secret.openai_api_key.name
}

output "vpc_network" {
  description = "VPC network name"
  value       = google_compute_network.sandbox_vpc.name
}

output "subnet" {
  description = "Subnet name"
  value       = google_compute_subnetwork.sandbox_subnet.name
}

# =============================================================================
# SSH Command Helper
# =============================================================================

output "ssh_command" {
  description = "Command to SSH into the sandbox VM via IAP"
  value       = "gcloud compute ssh ${google_compute_instance.sandbox_vm.name} --zone=${google_compute_instance.sandbox_vm.zone} --tunnel-through-iap"
}

output "scp_command" {
  description = "Command to SCP files to the sandbox VM via IAP"
  value       = "gcloud compute scp --zone=${google_compute_instance.sandbox_vm.zone} --tunnel-through-iap LOCAL_FILE ${google_compute_instance.sandbox_vm.name}:~/"
}

# =============================================================================
# Secret Setup Command
# =============================================================================

output "set_openai_key_command" {
  description = "Command to set the OpenAI API key in Secret Manager"
  value       = "echo -n 'YOUR_OPENAI_API_KEY' | gcloud secrets versions add ${google_secret_manager_secret.openai_api_key.secret_id} --data-file=-"
}
