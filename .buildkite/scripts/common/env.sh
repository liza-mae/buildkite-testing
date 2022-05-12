#!/usr/bin/env bash

export CI=true

# keys used to associate test group data in ci-stats with Jest execution order
export TEST_GROUP_TYPE_UNIT="Jest Unit Tests"
export TEST_GROUP_TYPE_INTEGRATION="Jest Integration Tests"
export TEST_GROUP_TYPE_FUNCTIONAL="Functional Tests"
