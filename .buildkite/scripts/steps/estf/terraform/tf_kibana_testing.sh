#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Buildkite script to run kibana functional tests pn ESS deployment
#
# Author: Liza Dayoub
# ----------------------------------------------------------------------------

set -euo pipefail

trap "cleanup" EXIT

cleanup() {
  dir=$(buildkite-agent meta-data get "estf-homedir-$ESTF_META_ID")
  cd $dir
  source .buildkite/scripts/steps/estf/terraform/tf_destroy_instance.sh
}

buildkite-agent meta-data set "estf-homedir-$ESTF_META_ID" "$(pwd)"

source .buildkite/scripts/steps/estf/terraform/tf_create_instance.sh

# Test on BK
sleep 60000
# TODO:
#source .buildkite/scripts/steps/estf/kibana/run_kibana_tests.sh