#!/bin/bash

set -eu

source .buildkite/scripts/common/util.sh

echo '--- Pick Test Group Run Order'
node "$(dirname "${0}")/pick_test_group_run_order.js"

