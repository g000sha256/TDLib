#!/usr/bin/env bash

set -e

# Read all commands before checkout
{
    git checkout -B main origin/main
    git rebase --no-rebase-merges upstream/master
    git push --force origin main
}
