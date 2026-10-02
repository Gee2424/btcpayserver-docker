#!/bin/bash
# Generate docker-compose.dokploy.yml for a Dokploy "Git" Compose service.
# Run from anywhere; writes to the repository root. Does not touch Generated/
# or secrets/. Requires docker and jq.

set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
: "${BTCPAYGEN_DOCKER_IMAGE:=btcpayserver/docker-compose-generator}"

export BTCPAYGEN_CRYPTO1="${BTCPAYGEN_CRYPTO1:-btc}"
export BTCPAYGEN_REVERSEPROXY="nginx"
export BTCPAYGEN_LIGHTNING="${BTCPAYGEN_LIGHTNING:-lnd}"
export BTCPAYGEN_ADDITIONAL_FRAGMENTS="${BTCPAYGEN_ADDITIONAL_FRAGMENTS:-opt-save-storage-s;opt-more-memory}"
# Traefik terminates TLS, and the host SSH integration is not wanted on Dokploy.
export BTCPAYGEN_EXCLUDE_FRAGMENTS="${BTCPAYGEN_EXCLUDE_FRAGMENTS:-nginx-https;btcpay-host}"

out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT
chmod 777 "$out"

docker run --rm \
    -v "$out:/app/Generated" \
    -v "$repo/docker-compose-generator/docker-fragments:/app/docker-fragments:ro" \
    -v "$repo/docker-compose-generator/crypto-definitions.json:/app/crypto-definitions.json:ro" \
    -e BTCPAYGEN_CRYPTO1 -e BTCPAYGEN_REVERSEPROXY -e BTCPAYGEN_LIGHTNING \
    -e BTCPAYGEN_ADDITIONAL_FRAGMENTS -e BTCPAYGEN_EXCLUDE_FRAGMENTS \
    "$BTCPAYGEN_DOCKER_IMAGE" >/dev/null

# The generated file lives in Generated/ and uses paths relative to it. Dokploy
# runs it from the repository root, with file mounts under ../files.
target="$repo/docker-compose.dokploy.yml"
sed -e 's#"\.\./nginx:#"./nginx:#' \
    -e 's#"\./torrc\.tmpl:#"./Generated/torrc.tmpl:#' \
    -e 's#file: \.\./secrets/#file: ../files/#' \
    "$out/docker-compose.generated.yml" >"$target"

if grep -nE '\.\./(nginx|secrets)|"\./torrc' "$target"; then
    echo "Unrewritten relative path remains in $target" >&2
    exit 1
fi

# Required Nginx routes are normally symlinked by btcpay-routes; Dokploy never
# runs it, so commit the links for the selected fragments.
mkdir -p "$repo/nginx/enabled-routes"
while IFS= read -r route; do
    ln -sfn "../routes/$route.conf" "$repo/nginx/enabled-routes/$route.conf"
done < <(jq -r '.requiredRoutes[]' "$out/manifest.json")

echo "Wrote $target"
echo "Secrets declared: $(jq -r '.secrets | join(", ")' "$out/manifest.json")"
