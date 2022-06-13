#!/bin/sh

set -xe

yarn install --frozen-lockfile

yarn build

yarn test
