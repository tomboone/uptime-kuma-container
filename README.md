# Personal Uptime Kuma

Uptime checks for the personal sites and jobs, plus the push monitor for kumadrome's nightly B2 backup.
It runs in Docker on the home server `kumadrome` (a 2011 Mac mini, Ubuntu 26.04), with its SQLite
database on the USB drive at `/mnt/music`. It is reachable on the **personal tailnet** only, at
`https://kuma.tail1afe5a.ts.net`, through its own Tailscale sidecar container.

This is not the business Uptime Kuma, which runs next to it (`neuroticsasquat-ch/ops`,
`monitoring/uptime-kuma/`). The two have separate stacks, data, ports (`127.0.0.1:3001` business,
`127.0.0.1:3002` personal) and tailnets. The host itself is on no tailnet.

Until 2026-10-17 this Kuma ran on Azure App Service with its database on an Azure Files share. SQLite
over SMB corrupted it, so it moved here. See the log. `Dockerfile`, `infra/` and `.github/workflows/`
are the Azure deployment and go when it is retired.

| File | Purpose |
| --- | --- |
| `docker-compose.yml` | Two services. `tailscale`: `tailscale/tailscale:stable` as tailnet node `kuma`, userspace networking, state from `TS_STATE_HOST_DIR`, serving HTTPS on tailnet port 443. `uptime-kuma`: `louislam/uptime-kuma:1`, data from `KUMA_DATA_DIR`, publishing `127.0.0.1:3002` only. |
| `tailscale/serve.json` | HTTPS on `:443` with a Tailscale certificate, proxied to `http://uptime-kuma:3001`. |
| `.env.example` | The settings. Copy to `.env` (gitignored) on the host. |

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
because the host is on no tailnet.

## Backup

Everything is in `KUMA_DATA_DIR`, chiefly `kuma.db`. SQLite's online backup API makes a consistent copy
while Kuma runs:

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
