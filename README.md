# Personal Uptime Kuma

Uptime checks for the personal sites and jobs, plus the push monitor for kumadrome's nightly B2 backup.
It runs in Docker on the home server `kumadrome` (a 2011 Mac mini, Ubuntu 26.04), with its SQLite
database on the USB drive at `/mnt/music`. It is reachable on the **personal tailnet** only, at
`https://kuma.tail1afe5a.ts.net`, through its own Tailscale sidecar container.

This is not the business Uptime Kuma, which runs next to it (`neuroticsasquat-ch/ops`,
`monitoring/uptime-kuma/`). The two have separate stacks, data, ports (`127.0.0.1:3001` business,
`127.0.0.1:3002` personal) and tailnets. The host itself is on no tailnet.

Until 2026-10-17 this Kuma ran on Azure App Service with its database on an Azure Files share. SQLite
over SMB corrupted it, so it moved here and the Azure deployment was retired. See the log.

| File | Purpose |
| --- | --- |
| `docker-compose.yml` | Two services. `tailscale`: `tailscale/tailscale:stable` as tailnet node `kuma`, userspace networking, state from `TS_STATE_HOST_DIR`, serving HTTPS on tailnet port 443. `uptime-kuma`: `louislam/uptime-kuma:1`, data from `KUMA_DATA_DIR`, publishing `127.0.0.1:3002` only. |
| `tailscale/serve.json` | HTTPS on `:443` with a Tailscale certificate, proxied to `http://uptime-kuma:3001`. |
| `.env.example` | The settings. Copy to `.env` (gitignored) on the host. |
| `Taskfile.yml` | `task up`, `ps`, `logs`, `upgrade`, run on the host. |

## Deploy

On the host, as `tom` (in the `docker` group):

```bash
# read-only deploy key behind a host alias (~/.ssh/config: github-kuma → github.com, ~/.ssh/kuma_personal_deploy)
git clone git@github-kuma:tomboone/uptime-kuma-container.git ~/kuma-personal
cd ~/kuma-personal
mkdir -p /mnt/music/uptime-kuma-personal /mnt/music/uptime-kuma-personal-tailscale
cp .env.example .env && chmod 600 .env && $EDITOR .env   # TS_AUTHKEY from the personal tailnet
docker compose up -d
```

1. `docker compose exec tailscale tailscale status | head -1` shows `kuma`, and
   `docker compose exec tailscale tailscale serve status` shows `https://kuma.<tailnet>.ts.net`
   → `http://uptime-kuma:3001`.
2. Blank `TS_AUTHKEY=` in `.env`. In the personal tailnet's *Machines*, choose *Disable key expiry*
   on `kuma`.
3. `docker compose ps` shows `kuma-personal` as `(healthy)`. `ss -ltn | grep 3002` lists only
   `127.0.0.1:3002`.

**Push URLs from jobs on this host** use `http://127.0.0.1:3002/api/push/<token>`, not the tailnet URL,
because the host is on no tailnet. **Push URLs from other containers** use `http://uptime-kuma:3001/api/push/<token>`
over the `kuma-push` network, which this stack creates. The other stack declares it `external`. The weekly movie
email does this.

## Backup

Everything is in `KUMA_DATA_DIR`, chiefly `kuma.db`. **Nightly:** the B2 job in `tomboone/navidrome`
(`backup/navidrome-backup.sh`, `KUMA_DB`) takes an online-backup copy at about 04:00. The copy is
integrity-checked and gzipped into `/mnt/music/uptime-kuma-personal-backups` (14 days kept) and synced
to `b2:tomboone-music-backup/kuma-personal-backups`. **By hand**, SQLite's online backup API makes a
consistent copy while Kuma runs:

```bash
sqlite3 /mnt/music/uptime-kuma-personal/kuma.db ".backup '/mnt/music/kuma-personal-$(date +%F).db'"
```

**Restore:** `docker compose stop uptime-kuma`, delete `kuma.db-wal` and `kuma.db-shm`, put the copy in
place as `kuma.db`, then `docker compose start uptime-kuma`.

## Upgrade

```bash
cd ~/kuma-personal && git pull
docker compose pull && docker compose up -d
docker image prune -f
```

## Log

Append to the log at the bottom; never rewrite it.

### 2026-10-17 — Moved from Azure to kumadrome

**Symptom.** Every refresh showed all monitors at zero. **Cause.** The container log was full of
`SQLITE_CORRUPT: database disk image is malformed`, on every read of `heartbeat`. Kuma restarted each
monitor every minute, and the share also held a 361 MB `error.log`. The database lived on an Azure Files
share mounted at `/app/data`. That is SMB, and Kuma's docs say network filesystems are not supported
for SQLite. The app ran on one worker with `alwaysOn`, so neither instance-hopping nor restarts
explained it. The container had last restarted at 2026-10-17 03:01Z.

**Recovery.** `kuma.db` (78 MB) and its WAL were downloaded from the share. `PRAGMA integrity_check`
reported broken B-tree pages in one table. `sqlite3 .recover` (3.54.0) rebuilt a database that passes
`integrity_check`, with all 7 monitors, the user, the notification and the settings
(`database_version` 10). It kept 499,618 heartbeats, from 2026-03-22 to **2026-06-18**. The corrupt
pages held the history after that, and `.recover` put 157,335 unparented rows in `lost_and_found`.
That table was dropped, so history from 2026-06-18 to 2026-10-17 is gone. The last good heartbeat
suggests the database had been corrupt since mid-June.

**Cutover.** The recovered database went to `/mnt/music/uptime-kuma-personal/kuma.db`, with
*Primary Base URL* set to `https://kuma.tail1afe5a.ts.net`.

- **Up and clean.** Kuma reached `(healthy)` with no `SQLITE_CORRUPT`. Within a minute all six HTTP
  monitors recorded `200 - OK` heartbeats.
- **Tailnet.** The sidecar joined the personal tailnet as `kuma` (`100.113.69.20`), and its certificate
  was issued at 19:41:31Z. `TS_AUTHKEY` was then blanked.
- **Push.** `kumadrome/navidrome-backup` (monitor 8) got its first-ever heartbeat from the Navidrome
  backup job over `127.0.0.1:3002`. Its earlier pushes never fired; see the navidrome repo's log.
- **Azure.** The App Service `app-uptime-kuma-tbc` was **stopped**, not deleted. Its resources,
  including the corrupt share, stay until the retirement is confirmed.

### 2026-10-17 — Azure retired

The resource group `rg-uptime-kuma` (the App Service, the storage account and the corrupt share) was
deleted by hand. `az group exists` returns `false`. The repo no longer holds the Azure deployment:
`Dockerfile`, `infra/` (OpenTofu), the build and deploy workflows, `dependabot.yml` and the devcontainer
are gone, and `Taskfile.yml` now wraps the compose stack. The workflows were deleted in the same commit
that merged to `main`, so the merge triggered no build or `tofu apply`.

Left outside the resource group, still to clear:

- the OpenTofu state blob `uptime-kuma-container.tfstate` in `tbcterraformstate/tfstate` (resource group
  `rg-tbc-app-services`). It still lists the deleted resources.
- the GHCR image `ghcr.io/tomboone/uptime-kuma-container` (9 versions). Nothing pulls it any more.

The power-restore unplug test on kumadrome also passed: pulled, plugged back, booted on its own.
