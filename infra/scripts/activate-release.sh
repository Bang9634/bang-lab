#!/usr/bin/env bash
set -euo pipefail

release=${1:?Release identifier required}
sha=${2:?Commit SHA required}
site_url=${3:?HTTPS origin required}
[[ $release =~ ^[a-f0-9]{40}-[0-9]+-[0-9]+$ ]] || exit 1
[[ $sha =~ ^[a-f0-9]{40}$ ]] || exit 1
[[ $site_url =~ ^https://[a-zA-Z0-9][a-zA-Z0-9.-]*(:[0-9]{1,5})?$ ]] || exit 1

base=/var/www/bang-lab
destination="$base/releases/$release"

# Keep the lock through activation, verification and any rollback.
exec 9> "$base/.deploy.lock"
flock -w 60 9
test -s "$destination/index.html"
test -s "$destination/404.html"
[[ $(cat "$destination/release.txt") == "$sha" ]] || exit 1
test -L "$base/current"
previous=$(readlink -f "$base/current")
[[ $previous == "$base/releases/"* && -d $previous ]] || exit 1

next="$base/.current-$release"
switched=false
finished=false
cleanup() {
  status=$?
  trap - EXIT
  if [[ $switched == true && $finished == false ]]; then
    echo "Verification failed; restoring previous release." >&2
    rm -f -- "$next"
    ln -s "$previous" "$next" && mv -Tf "$next" "$base/current" || {
      echo "Rollback failed; administrator intervention required." >&2
      exit 1
    }
  fi
  rm -f -- "$next"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

ln -s "$destination" "$next"
switched=true
mv -Tf "$next" "$base/current"

for attempt in {1..5}; do
  if actual=$(curl --fail --silent --show-error --connect-timeout 10 --max-time 20 \
      "$site_url/release.txt?release=$release") && [[ $actual == "$sha" ]] &&
      curl --fail --silent --show-error --connect-timeout 10 --max-time 20 \
        --output /dev/null "$site_url/"; then
    finished=true
    echo "Deployment verified: $release"
    exit 0
  fi
  sleep 3
done
echo "New release was not served correctly over HTTPS." >&2
exit 1
