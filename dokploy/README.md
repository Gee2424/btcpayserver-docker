# Dokploy deployment

`docker-compose.dokploy.yml` (repository root) is the generator output for
Bitcoin + LND with `opt-save-storage-s`, with `nginx-https` and `btcpay-host`
excluded. Regenerate it with `dokploy/generate.sh`; do not edit it by hand.

Dokploy's Traefik terminates HTTPS and forwards to the bundled `nginx` service.

## Dokploy service

- Type: Compose, source Git, this branch, compose path `./docker-compose.dokploy.yml`.
- File mount named `tor_password`: any random single-line value.
- Domain: `pay.arkdemia.top` on service `nginx`, container port `80`, HTTPS on.

## Environment

```
BTCPAY_HOST=pay.arkdemia.top
BTCPAY_ADDITIONAL_HOSTS=
BTCPAY_PROTOCOL=https
NBITCOIN_NETWORK=mainnet
TRUST_DOWNSTREAM_PROXY=true
REVERSEPROXY_HTTP_PORT=127.0.0.1:10080
BTCPAY_ANNOUNCEABLE_HOST=pay.arkdemia.top
LIGHTNING_ALIAS=<node name>
```

`REVERSEPROXY_HTTP_PORT` binds the backend to loopback so only Traefik can reach
it. `TRUST_DOWNSTREAM_PROXY=true` is unsafe if that port is ever public; see
[External Reverse Proxy](../docs/networking.md#external-reverse-proxy).

Host scripts such as `btcpay-update.sh` and `btcpay-backup.sh` do not apply here.
Update images by regenerating the file and redeploying; back up the Docker volumes.
