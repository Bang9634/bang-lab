#!/usr/bin/env bash
set -euo pipefail

for name in DEPLOY_HOST DEPLOY_USER DEPLOY_PORT DEPLOY_SSH_KEY DEPLOY_KNOWN_HOSTS SITE_URL GITHUB_SHA GITHUB_RUN_ID GITHUB_RUN_ATTEMPT; do
  if [[ -z ${!name:-} ]]; then
    echo "Missing required setting: $name" >&2
    exit 1
  fi
done

# Validate values before inserting them into SSH configuration or remote commands.
[[ $DEPLOY_HOST =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]] || exit 1
[[ $DEPLOY_USER == deploy ]] || exit 1
[[ $DEPLOY_PORT =~ ^[0-9]{1,5}$ ]] || exit 1
(( 10#$DEPLOY_PORT > 0 && 10#$DEPLOY_PORT <= 65535 )) || exit 1
[[ $SITE_URL =~ ^https://[a-zA-Z0-9][a-zA-Z0-9.-]*(:[0-9]{1,5})?$ ]] || exit 1
[[ $GITHUB_SHA =~ ^[a-f0-9]{40}$ ]] || exit 1
[[ $GITHUB_RUN_ID =~ ^[0-9]+$ && $GITHUB_RUN_ATTEMPT =~ ^[0-9]+$ ]] || exit 1
test -s deploy-dist/index.html
test -s deploy-dist/404.html
[[ $(cat deploy-dist/release.txt) == "$GITHUB_SHA" ]] || exit 1

ssh_dir=$(mktemp -d)
trap 'rm -rf -- "$ssh_dir"' EXIT
chmod 700 "$ssh_dir"
printf '%s\n' "$DEPLOY_SSH_KEY" > "$ssh_dir/key"
printf '%s\n' "$DEPLOY_KNOWN_HOSTS" > "$ssh_dir/known_hosts"
chmod 600 "$ssh_dir/key" "$ssh_dir/known_hosts"
cat > "$ssh_dir/config" <<EOF
Host production
  HostName $DEPLOY_HOST
  User $DEPLOY_USER
  Port $DEPLOY_PORT
  IdentityFile $ssh_dir/key
  UserKnownHostsFile $ssh_dir/known_hosts
  GlobalKnownHostsFile /dev/null
  StrictHostKeyChecking yes
  IdentitiesOnly yes
  BatchMode yes
  ConnectTimeout 15
  ServerAliveInterval 15
  ServerAliveCountMax 3
EOF

release="${GITHUB_SHA}-${GITHUB_RUN_ID}-${GITHUB_RUN_ATTEMPT}"
destination="/var/www/bang-lab/releases/$release"
ssh -F "$ssh_dir/config" production "mkdir -m 755 '$destination'"
rsync -rlt --chmod=D755,F644 -e "ssh -F $ssh_dir/config" \
  deploy-dist/ "production:$destination/"
ssh -F "$ssh_dir/config" production \
  "bash -s -- '$release' '$GITHUB_SHA' '$SITE_URL'" < infra/scripts/activate-release.sh
