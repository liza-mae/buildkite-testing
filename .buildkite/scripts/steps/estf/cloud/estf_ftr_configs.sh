#!/usr/bin/env bash

set -euo pipefail

# Clone kibana repo from git reference
git clone --reference /var/lib/gitmirrors/https---github-com-elastic-kibana-git https://github.com/elastic/kibana.git
cd kibana

# Checkout kibana commit
#git checkout -f $(buildkite-agent meta-data get "estf-kibana-hash-$ESTF_META_ID")

export JOB_NUM=$BUILDKITE_PARALLEL_JOB
export JOB=ftr-configs-${JOB_NUM}

FAILED_CONFIGS_KEY="${BUILDKITE_STEP_ID}${BUILDKITE_PARALLEL_JOB:-0}"

# a FTR failure will result in the script returning an exit code of 10
exitCode=0

configs="${FTR_CONFIG:-}"

# The first retry should only run the configs that failed in the previous attempt
# Any subsequent retries, which would generally only happen by someone clicking the button in the UI, will run everything
if [[ ! "$configs" && "${BUILDKITE_RETRY_COUNT:-0}" == "1" ]]; then
  configs=$(buildkite-agent meta-data get "$FAILED_CONFIGS_KEY" --default '')
  if [[ "$configs" ]]; then
    echo "--- Retrying only failed configs"
    echo "$configs"
  fi
fi

if [[ "$configs" == "" ]]; then
  echo "--- downloading ftr test run order"
  buildkite-agent artifact download ftr_run_order.json .
  configs=$(jq -r '.groups[env.JOB_NUM | tonumber].names | .[]' ftr_run_order.json)
fi

failedConfigs=""
results=()

while read -r config; do
  if [[ ! "$config" ]]; then
    continue;
  fi

  echo "--- $ node scripts/functional_tests --bail --config $config"
  start=$(date +%s)

  # prevent non-zero exit code from breaking the loop
  set +e;
  node scripts/functional_test_runner \
            --es-version $ESTF_CLOUD_VERSION \
            --exclude-tag skipCloud \
            --include-tag testInCloud \
            --config="$config"
  lastCode=$?
  set -e;

  timeSec=$(($(date +%s)-start))
  if [[ $timeSec -gt 60 ]]; then
    min=$((timeSec/60))
    sec=$((timeSec-(min*60)))
    duration="${min}m ${sec}s"
  else
    duration="${timeSec}s"
  fi

  results+=("- $config
    duration: ${duration}
    result: ${lastCode}")

  if [ $lastCode -ne 0 ]; then
    exitCode=10
    echo "FTR exited with code $lastCode"
    echo "^^^ +++"

    if [[ "$failedConfigs" ]]; then
      failedConfigs="${failedConfigs}"$'\n'"$config"
    else
      failedConfigs="$config"
    fi
  fi
done <<< "$configs"

if [[ "$failedConfigs" ]]; then
  buildkite-agent meta-data set "$FAILED_CONFIGS_KEY" "$failedConfigs"
fi

echo "--- FTR configs complete"
printf "%s\n" "${results[@]}"
echo ""

exit $exitCode