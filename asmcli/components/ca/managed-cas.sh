x_configure_managed_cas() {
  local CUSTOM_OVERLAY; CUSTOM_OVERLAY="$(context_get-option "CUSTOM_OVERLAY")"

  CUSTOM_OVERLAY="${OPTIONS_DIRECTORY}/managed_cas.yaml,${CUSTOM_OVERLAY}"
  context_set-option "CUSTOM_OVERLAY" "${CUSTOM_OVERLAY}"

  local CLUSTER_NAME; CLUSTER_NAME="$(context_get-option "CLUSTER_NAME")"
  local CLUSTER_LOCATION; CLUSTER_LOCATION="$(context_get-option "CLUSTER_LOCATION")"
  local USE_HUB_WIP; USE_HUB_WIP="$(context_get-option "USE_HUB_WIP")"
  local HUB_MEMBERSHIP_ID; HUB_MEMBERSHIP_ID="$(context_get-option "HUB_MEMBERSHIP_ID")"
  local HUB_IDP_URL; HUB_IDP_URL="$(context_get-option "HUB_IDP_URL")"

  if [[ "${USE_HUB_WIP}" -eq 1 ]]; then
    kpt cfg set asm anthos.servicemesh.idp-url "${HUB_IDP_URL}"
  else
    kpt cfg set asm anthos.servicemesh.idp-url "https://container.googleapis.com/v1/projects/${PROJECT_ID}/locations/${CLUSTER_LOCATION}/clusters/${CLUSTER_NAME}"
  fi

  configure_trust_domain_aliases
}

x_enable_gke_hub_api() {
  local GKEHUB_API; GKEHUB_API="$1"
  local FLEET_ID; FLEET_ID="$(context_get-option "FLEET_ID")"

  info "Enabling the GKE Hub API for ${FLEET_ID} ..."
  retry 2 run_command gcloud services enable --project="${FLEET_ID}" "${GKEHUB_API}"
}

x_enable_workload_certificate_api() {
  local WORKLOAD_CERT_API; WORKLOAD_CERT_API="$1"
  local FLEET_ID; FLEET_ID="$(context_get-option "FLEET_ID")"

  info "Enabling the workload certificate API for ${FLEET_ID} ..."
  retry 2 run_command gcloud services enable --project="${FLEET_ID}" "${WORKLOAD_CERT_API}"
}

x_enable_workload_certificate_on_fleet() {
  local GKEHUB_API; GKEHUB_API="$1"
  local FLEET_ID; FLEET_ID="$(context_get-option "FLEET_ID")"

  info "Enabling the workload identity platform on ${FLEET_ID} ..."
  exit_if_no_auth_token
  local AUTHTOKEN; AUTHTOKEN="$(get_auth_token)"

  # gcloud command is not ready yet, use curl command instead.
  # retry 2 run_command gcloud alpha container fleet workload-certificate enable --provision-google-ca --project="${FLEET_ID}"
  local BODY; BODY="{
    'spec': {
      'workloadcertificate': {
        'provision_google_ca': 'ENABLED'
      }
    }
  }"

  curl -H "Authorization: Bearer ${AUTHTOKEN}" \
      -X POST -H "Content-Type: application/json" -H "Accept: application/json" \
      -d "${BODY}" \
      "https://${GKEHUB_API}/v1alpha/projects/${FLEET_ID}/locations/global/features?feature_id=workloadcertificate"
}

x_enable_workload_certificate_on_membership() {
  local GKEHUB_API; GKEHUB_API="${1}"
  local FLEET_ID; FLEET_ID="${2}"
  local MEMBERSHIP_NAME; MEMBERSHIP_NAME="${3}"

  info "Enabling the workload identity platform certificate for the membership ${MEMBERSHIP_NAME}  ..."
  exit_if_no_auth_token
  local AUTHTOKEN; AUTHTOKEN="$(get_auth_token)"


  # gcloud command is not ready yet, use curl command instead
  # retry 2 run_command gcloud alpha container fleet workload-certificate update --memberships="${MEMBERSHIP_NAME}" --enable --project="${FLEET_ID}"
  ENABLEFEATURE="{
    'membership_specs': {
      'projects/${FLEET_ID}/locations/global/memberships/${MEMBERSHIP_NAME}': {
        'workloadcertificate': {
          'certificate_management': 'ENABLED'
        }
      }
    }
  }"

  curl -H "Authorization: Bearer ${AUTHTOKEN}" \
     -X PATCH -H "Content-Type: application/json" -H "Accept: application/json" \
     -d "${ENABLEFEATURE}" "https://${GKEHUB_API}/v1alpha/projects/${FLEET_ID}/locations/global/features/workloadcertificate?update_mask=membership_specs"
}
