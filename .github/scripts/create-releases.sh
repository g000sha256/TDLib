#!/usr/bin/env bash

set -e

upstream_commit=$(git merge-base HEAD upstream/master)
version_pattern='^Update version to ([0-9]+\.[0-9]+\.[0-9]+)\.$'
tag_pattern='v[0-9]*.[0-9]*.[0-9]*'
latest_tag=$(git describe --tags --abbrev=0 --match "$tag_pattern" "$upstream_commit" 2>/dev/null || true)
revisions=("$upstream_commit")

if [ -n "$latest_tag" ] && latest_parent=$(git rev-parse --verify --quiet "refs/tags/${latest_tag}^"); then
    revisions+=("^$latest_parent")
fi

previous_upstream=
commit_heading='📋 Processing new commits'
if [[ ${PREVIOUS_MAIN:-} =~ ^[0-9a-f]{40}$ && $PREVIOUS_MAIN =~ [1-9a-f] ]]; then
    if ! git cat-file -e "$PREVIOUS_MAIN^{commit}" 2>/dev/null; then
        git fetch --no-tags origin "$PREVIOUS_MAIN" >/dev/null 2>&1 || true
    fi
    previous_upstream=$(git merge-base "$PREVIOUS_MAIN" "$upstream_commit" 2>/dev/null) || true
fi

if [ -z "$previous_upstream" ] && [ -n "$latest_tag" ]; then
    previous_upstream="refs/tags/$latest_tag"
    commit_heading="📋 Upstream commits since $latest_tag"
fi

if [ -n "$previous_upstream" ]; then
    new_commits=$(git log --reverse --format='  📝 %h %s' "$previous_upstream..$upstream_commit")
    printf '\n%s\n%s\n' "$commit_heading" "${new_commits:-  ℹ️ No new upstream commits}"
fi

commits=$(git log --reverse --format='%H %s' --extended-regexp --grep="$version_pattern" "${revisions[@]}")
if [ -z "$commits" ]; then
    printf '\nℹ️ No version updates found\n'
    exit 0
fi

printf '\n🏷️ Version tags and releases\n'
while read -r commit subject; do
    [[ $subject =~ $version_pattern ]] || continue
    version=${BASH_REMATCH[1]}
    tag=v$version

    if git show-ref --verify --quiet "refs/tags/$tag"; then
        if [ "$(git rev-parse "refs/tags/$tag^{commit}")" != "$commit" ]; then
            echo "Tag $tag points to a different commit than $commit" >&2
            exit 1
        fi
        if gh release view "$tag" >/dev/null 2>&1; then
            printf '  ℹ️ %s already published\n' "$tag"
            continue
        fi
        printf '  ℹ️ Tag %s already exists\n' "$tag"
    else
        git tag "$tag" "$commit"
        printf '  ✅ Created tag %s at %s\n' "$tag" "${commit:0:7}"
    fi

    body="- 🔄 Synced from [tdlib/td@${commit:0:7}](https://github.com/tdlib/td/commit/${commit})"
    if prev_tag=$(git describe --tags --abbrev=0 --match "$tag_pattern" "$commit^" 2>/dev/null); then
        commit_count=$(git rev-list --count "refs/tags/$prev_tag..$commit")
        commits_word="commits"
        [ "$commit_count" -eq 1 ] && commits_word="commit"
        body+=$'\n'
        body+="- 📋 **${commit_count} ${commits_word}** from upstream — see full diff "
        body+="[${prev_tag}...${tag}](https://github.com/g000sha256/TDLib/compare/${prev_tag}...${tag})"
    fi

    git push origin "refs/tags/$tag"
    release_url=$(gh release create "$tag" --verify-tag --title "$version" --notes "$body")
    printf '  📦 Published %s %s\n' "$tag" "$release_url"
done <<< "$commits"
