# 1panel-ssl-from-asus-router

Pull TLS key and certificate from an **Asus stock router** (SSH) and upload them to **1Panel** (website SSL API). Typical use: keep the router’s DDNS cert in sync with **Website → SSL**; files under **`./ssl`** can also be used by other apps (e.g. Home Assistant).

**Docker Hub:** [dylansea/1panel-ssl-from-asus-router](https://hub.docker.com/r/dylansea/1panel-ssl-from-asus-router) — published images use tags **`router-latest`** / **`router-<version>`** and **`1panel-latest`** / **`1panel-<version>`** in that repository.

## About

**1panel-ssl-from-asus-router** uses two small **Alpine** images: **`Dockerfile.router`** (`openssh-client`, `sshpass`, `run.sh`) and **`Dockerfile.1panel`** (`curl`, `jq`, `openssl`, `push-1panel.sh`). Configure with **`docker-compose.yaml`** and **`.env`**. The router step runs **`ssh-keyscan`**, then **`sshpass` + `ssh`** to `cat` the key and cert paths (no SCP on stock firmware).

**Run (Docker Hub — default):** `cp .env.example .env`, edit `.env`, then `docker compose pull`, then `./sync.sh` or the `docker compose run` commands below. Base compose has **no `build:`**; images are **`dylansea/1panel-ssl-from-asus-router:router-latest`** and **`:1panel-latest`** ([Docker Hub](https://hub.docker.com/r/dylansea/1panel-ssl-from-asus-router)).

**Run (local build — develop / debug Dockerfile or scripts):** use the overlay so local tags **`*-local`** never overwrite pulled **`*-latest`**:

```bash
docker compose -f docker-compose.yaml -f docker-compose.local.yaml build
docker compose -f docker-compose.yaml -f docker-compose.local.yaml run --rm ssl-from-router
docker compose -f docker-compose.yaml -f docker-compose.local.yaml run --rm ssl-push-1panel
```

- **Both steps in order** (Hub): `./sync.sh`, or: `docker compose run --rm ssl-from-router && docker compose run --rm ssl-push-1panel`
- **Debug one side only (Hub):** `docker compose run --rm ssl-from-router` **or** `docker compose run --rm ssl-push-1panel`

**Security note:** Do not commit `.env` with real passwords. `sshpass` supplies the password non-interactively; on some systems it can be visible in process listings while the command runs. Prefer a strong password and keep SSH on a trusted LAN.

## Environment variables


| Variable              | Description                                | Required / default     |
| --------------------- | ------------------------------------------ | ---------------------- |
| `ROUTER_USER`         | SSH username for the router                | Required               |
| `ROUTER_IP`           | IP address or hostname of the router       | Required               |
| `ROUTER_SSH_PORT`     | SSH port                                   | Optional, default `22` |
| `ROUTER_PASSWORD`     | SSH password                               | Required               |
| `KEY_PATH_ON_ROUTER`  | Path to the private key file on the router | Required               |
| `CERT_PATH_ON_ROUTER` | Path to the certificate file on the router | Required               |


## Push certificate to 1Panel — **Website → SSL** (not panel system HTTPS)

Upload `./ssl/key.pem` and `./ssl/cert.pem` to **1Panel’s website certificate store** (same as **网站 → SSL → 上传证书**, paste mode):

`docker compose run --rm ssl-push-1panel`  
(or run **`./sync.sh`** after the router step has succeeded).

This calls **`POST {ONEPANEL_BASE_URL}{ONEPANEL_API_PATH}`** (default **`/api/v2/websites/ssl/upload`**) with JSON: `type: paste`, `privateKey`, `certificate`, `sslID`, `description`. It does **not** use the panel’s **system HTTPS** API (`/api/v2/core/settings/ssl/update`).

**Compose / shell:** `export ONEPANEL_*` overrides `.env`. For HTTPS-only panels use `https://` and `ONEPANEL_SKIP_TLS_VERIFY=1` when needed; run `unset ONEPANEL_BASE_URL` if `.env` changes are ignored.

Enable **API**, add the **Docker host IP** to the allowlist, and set:


| Variable                   | Description                                                                                                 | Required / default                    |
| -------------------------- | ----------------------------------------------------------------------------------------------------------- | ------------------------------------- |
| `ONEPANEL_BASE_URL`        | API root: scheme + host + port, no trailing slash, **no** browser-only secure-entrance path                 | Required                              |
| `ONEPANEL_API_KEY`         | Panel API key                                                                                               | Required                              |
| `ONEPANEL_API_PATH`        | Upload path (default **`/api/v2/websites/ssl/upload`**; older panels may use `/api/v1/websites/ssl/upload`) | Default `/api/v2/websites/ssl/upload` |
| `ONEPANEL_SSL_ID`          | Existing website SSL row **ID** to replace; `0` to create a new stored cert                                 | Default `0`                           |
| `ONEPANEL_SSL_DESCRIPTION` | Optional description string                                                                                 | Optional                              |
| `ONEPANEL_KEY_FILE`        | Private key path in the container                                                                           | Default `/ssl/key.pem`                |
| `ONEPANEL_CERT_FILE`       | Certificate PEM path in the container                                                                       | Default `/ssl/cert.pem`               |
| `ONEPANEL_SKIP_TLS_VERIFY` | `1` if the panel HTTPS cert is untrusted                                                                    | Default `0`                           |


Auth: [1Panel API manual](https://1panel.cn/docs/v2/dev_manual/api_manual/) — `1Panel-Token = md5('1panel' + API-Key + UnixTimestamp)` and `1Panel-Timestamp`.

**HTML instead of JSON:** use bare `http(s)://host:port` for `ONEPANEL_BASE_URL` (not the full browser login URL with entrance path). Ensure API is on and your IP is allowlisted.

## Attribution

**1panel-ssl-from-asus-router** continues from the idea of pulling router-held certs over SSH (instead of SCP on stock Asus). Upstream reference:

- [home-assistant-ssl-from-asus-router](https://github.com/s92025592025/home-assistant-ssl-from-asus-router) (s92025592025 / Flying_Apple_Pie) — original flow; this repo adds **1Panel** upload, **Docker Compose**, **env-based** config, and split images.


