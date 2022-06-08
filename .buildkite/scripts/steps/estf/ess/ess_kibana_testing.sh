#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Buildkite script to run kibana functional tests pn ESS deployment
#
# Author: Liza Dayoub
# ----------------------------------------------------------------------------

set -euo pipefail

trap "chdir; source .buildkite/scripts/steps/estf/ess/ess_shutdown_deployment.sh" EXIT

chdir() {
  dir=$(pwd)
  if [[ $(basename $dir) == "kibana" ]]; then
     cd ../
  fi
}

source .buildkite/scripts/steps/estf/ess/ess_create_deployment.sh
source .buildkite/scripts/steps/estf/ess/ess_run_kibana_tests.sh
