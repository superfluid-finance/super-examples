#!/bin/bash

# make sure that if any step fails, the script fails
set -xe

# build contracts
yarn
yarn build

# test contracts
yarn test
