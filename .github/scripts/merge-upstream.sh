#!/usr/bin/env bash

set -e

# Read all commands before checkout
{
    git checkout -B master origin/master
    git merge upstream/master -m "Merge branch 'upstream/master' into 'origin/master'"
    git push origin master
}
