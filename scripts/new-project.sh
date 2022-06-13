#!/bin/sh

# RUN FROM REPOSITORY'S ROOT DIRECTORY, NOT THIS DIRECTORY

set -xe

if [ -z $1 ]; then
    echo "MUST include project name. Example usage: \"yarn new-project my-project\"."
    exit 1
fi

mkdir examples/$1

cp scripts/build-and-test.template.sh examples/$1/build-and-test.sh

chmod 744 examples/$1/build-and-test.sh

touch examples/$1/README.md

echo "# $1" >> examples/$1/README.md
