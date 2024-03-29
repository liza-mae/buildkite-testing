#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Buildkite script to create cloud deployment
#
# Author: Liza Dayoub
# ----------------------------------------------------------------------------

set -euo pipefail

source .buildkite/scripts/common/util.sh

echo "--- Create ESS Deployment"

VAULT_ROLE_ID="$(retry 5 15 gcloud secrets versions access latest --secret=estf-vault-role-id)"
VAULT_SECRET_ID="$(retry 5 15 gcloud secrets versions access latest --secret=estf-vault-secret-id)"
VAULT_TOKEN=$(retry 5 30 vault write -field=token auth/approle/login role_id="$VAULT_ROLE_ID" secret_id="$VAULT_SECRET_ID")
retry 5 30 vault login -no-print "$VAULT_TOKEN"

EC_API_KEY="$(vault kv get --field apiKey secret/stack-testing/estf-cloud)"
export EC_API_KEY

ESTF_DEPLOYMENT_NAME="ESTF_Deployment_CI_$(uuidgen)"
ESTF_PLAN_FILE=".buildkite/scripts/steps/estf/ess/plans/ess_default_plan.json"
OUTPUT_FILE=$(mktemp --suffix ".json")

buildkite-agent meta-data set "estf-deployment-output-$ESTF_META_ID" $OUTPUT_FILE

if [[ ! -z "${ESTF_PLAN_SETTINGS:-}" ]] && [[ "${ESTF_PLAN_SETTINGS:-}" != "none" ]]; then
  settingsDir=".buildkite/scripts/steps/estf/kibana/settings"
  for plan in ${ESTF_PLAN_SETTINGS}; do
    branch=$(get_branch_from_version)
    versionDir="$settingsDir/$branch"
    if [[ -d $versionDir ]]; then
      versionFile="$versionDir/${plan}"
      if [[ ! -f $versionFile ]]; then
        continue
      fi
      settings=$(cat $versionFile)
    else
      defaultFile="$settingsDir/${plan}"
      if [[ ! -f $defaultFile ]]; then
        continue
      fi
      settings=$(cat $defaultFile)
    fi
    cat <<< $(jq ".resources.kibana[0].plan.kibana.user_settings_json += $settings" $ESTF_PLAN_FILE) > $ESTF_PLAN_FILE
  done
fi

validKibanaSizes="4 8"
if [[ ! -z ${ESTF_KIBANA_SIZE:-} ]] &&
   [[ "$validKibanaSizes" == *"${ESTF_KIBANA_SIZE:-}"* ]]; then
  size=$(( $ESTF_KIBANA_SIZE * 1024 ))
  cat <<< $(jq ".resources.kibana[0].plan.cluster_topology[0].size.value = $size" $ESTF_PLAN_FILE) > $ESTF_PLAN_FILE
fi

cloudVersion=$(get_cloud_version)
ecctl deployment create --track --output json --name $ESTF_DEPLOYMENT_NAME \
                        --version $cloudVersion --file $ESTF_PLAN_FILE &> "$OUTPUT_FILE"

ESTF_DEPLOYMENT_ID=$(jq -sr '.[0].id' "$OUTPUT_FILE")
ESTF_DEPLOYMENT_USERNAME=$(jq -sr '.[0].resources[0].credentials.username' "$OUTPUT_FILE")
ESTF_DEPLOYMENT_PASSWORD=$(jq -sr '.[0].resources[0].credentials.password' "$OUTPUT_FILE")
ESTF_KIBANA_URL=$(ecctl deployment show "$ESTF_DEPLOYMENT_ID" --kind kibana | jq -r '.info.metadata.aliased_url')
ESTF_ELASTICSEARCH_URL=$(ecctl deployment show "$ESTF_DEPLOYMENT_ID" --kind elasticsearch | jq -r '.info.metadata.aliased_url')
ESTF_KIBANA_HASH=$(curl -s -u "$ESTF_DEPLOYMENT_USERNAME:$ESTF_DEPLOYMENT_PASSWORD" $ESTF_KIBANA_URL/api/status | jq -r .version.build_hash)

buildkite-agent meta-data set "estf-deployment-id-$ESTF_META_ID" $ESTF_DEPLOYMENT_ID
buildkite-agent meta-data set "estf-kibana-hash-$ESTF_META_ID" $ESTF_KIBANA_HASH
buildkite-agent meta-data set "estf-elasticsearch-url-$ESTF_META_ID" $ESTF_ELASTICSEARCH_URL
buildkite-agent meta-data set "estf-kibana-url-$ESTF_META_ID" $ESTF_KIBANA_URL
buildkite-agent meta-data set "estf-deployment-password-$ESTF_META_ID" $ESTF_DEPLOYMENT_PASSWORD

cat << EOF | buildkite-agent annotate --style 'info' --context 'ess_deployments' --append
  $ESTF_META_ID deployment id: $ESTF_DEPLOYMENT_ID<br>
EOF
