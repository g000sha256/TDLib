#!/usr/bin/env bash

set -e

# Read all commands before checkout
{
    git checkout -B main origin/main
    git merge upstream/master -m "Merge branch 'upstream/master' into 'origin/main'"
    git push origin main
}
