#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
export GIT_AUTHOR_NAME=github-actions
export GIT_AUTHOR_EMAIL=41898282+github-actions[bot]@users.noreply.github.com
export GIT_COMMITTER_NAME=$GIT_AUTHOR_NAME
export GIT_COMMITTER_EMAIL=$GIT_AUTHOR_EMAIL

feed=$1
ref=refs/heads/update-feed
version=$(sed -n 's/^version=//p' "$feed" | sort -u)
[[ $version =~ ^[0-9]{6}[a-z]?$ ]]
blob=$(git hash-object -w "$feed")
tree=$(printf '100644 blob %s\tversion.ini\n' "$blob" | git mktree)

# A concurrent release can update the branch between our fetch and push.
for attempt in 1 2 3; do
    remote=$(git ls-remote origin "$ref")
    parent=()
    if [[ -n $remote ]]; then
        git fetch --no-tags origin "$ref"
        parent=(-p FETCH_HEAD)
        current=$(git show FETCH_HEAD:version.ini | sed -n 's/^version=//p' | sort -u)
        [[ $current =~ ^[0-9]{6}[a-z]?$ ]]
        if [[ $current == "$version" || $current > $version ]]; then
            exit 0
        fi
    fi
    commit=$(git commit-tree "$tree" "${parent[@]}" -m "Publish ConEmu $version update feed")
    if git push origin "$commit:$ref"; then
        exit 0
    fi
    sleep "$attempt"
done

echo "Failed to publish version.ini to $ref" >&2
exit 1
