# Personal Uptime Kuma — retired

**Retired on 2026-10-24.** This instance was merged into the Kuma deployed from
[`neuroticsasquat-ch/ops`](https://github.com/neuroticsasquat-ch/ops), in
[`monitoring/uptime-kuma`](https://github.com/neuroticsasquat-ch/ops/tree/main/monitoring/uptime-kuma).
Nothing in this repo is deployed any more.

- **URL:** `https://kuma.tail1afe5a.ts.net` is unchanged. The ops Kuma's sidecar took over the tailnet
  node name `kuma` in the 2026-10-25 cutover.
- **Monitors:** 8 of the 9 moved in the merge. The ninth, `argelander`, is recreated in the ops Kuma by
  its kumadrome-apps runbook.
- **Push URLs on kumadrome:** `http://127.0.0.1:3001/api/push/<token>` from the host (was `:3002`), or
  `http://uptime-kuma:3001/api/push/<token>` from containers over the `kuma-push` network, which the
  ops stack now creates.
- **Old data:** `/mnt/music/uptime-kuma-personal` is deleted in the ops teardown runbook.

The other files are kept for history. The README as it stood before retirement, with the deploy,
backup and upgrade steps, is at
[`75ceaa0`](https://github.com/tomboone/uptime-kuma-container/blob/75ceaa02e7e6fb2098b4a61c98073358da4b18a9/README.md).

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

### 2026-10-24 — Retired

The ops Kuma took over this instance's monitors in its merge-prep runbook (`docs/runbooks/kuma-merge.md`
in `neuroticsasquat-ch/ops`, NEU-1938). The stack was brought down and `kuma-push` moved to the ops stack.
The README was cut down to the retirement notice above (NEU-1955); the repo is archived in the ops
teardown runbook.
