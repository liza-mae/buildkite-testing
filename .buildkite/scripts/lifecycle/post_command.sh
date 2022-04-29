#!/usr/bin/env bash

# -- From github.com/elastic/kibana repo .buildkite/scripts/lifecycle/post_command.sh

set -euo pipefail

IS_TEST_EXECUTION_STEP="$(buildkite-agent meta-data get "${BUILDKITE_JOB_ID}_is_test_execution_step" --default '')"

if [[ "$IS_TEST_EXECUTION_STEP" == "true" ]]; then
  cd kibana
  echo "--- Upload Artifacts"
  buildkite-agent artifact upload 'target/junit/**/*'
  buildkite-agent artifact upload 'target/kibana-coverage/jest/**/*'
  buildkite-agent artifact upload 'target/kibana-coverage/functional/**/*'
  buildkite-agent artifact upload 'target/kibana-*'
  buildkite-agent artifact upload 'target/kibana-security-solution/**/*.png'
  buildkite-agent artifact upload 'target/test_failures/**/*'
  buildkite-agent artifact upload 'target/test-metrics/*'
  buildkite-agent artifact upload 'target/test-suites-ci-plan.json'
  buildkite-agent artifact upload 'test/**/screenshots/diff/*.png'
  buildkite-agent artifact upload 'test/**/screenshots/failure/*.png'
  buildkite-agent artifact upload 'test/**/screenshots/session/*.png'
  buildkite-agent artifact upload 'test/functional/failure_debug/html/*.html'
  buildkite-agent artifact upload 'x-pack/test/**/screenshots/diff/*.png'
  buildkite-agent artifact upload 'x-pack/test/**/screenshots/failure/*.png'
  buildkite-agent artifact upload 'x-pack/test/**/screenshots/session/*.png'
  buildkite-agent artifact upload 'x-pack/test/functional/apps/reporting/reports/session/*.pdf'
  buildkite-agent artifact upload 'x-pack/test/functional/failure_debug/html/*.html'
  buildkite-agent artifact upload '.es/**/*.hprof'
fi
