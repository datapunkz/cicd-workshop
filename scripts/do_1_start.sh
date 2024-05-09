#!/bin/bash

test -f .circleci/continue-config.yml && rm .circleci/continue-config.yml

cp scripts/do/configs/config_1.yml .circleci/config.yml

# Delete long running tests if they exist
rm -f test/long-running-*.test.js
