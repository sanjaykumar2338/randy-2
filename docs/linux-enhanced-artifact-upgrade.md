# Linux Enhanced Artifact Upgrade

FiveM for GTAV Enhanced uses the separate Cfx Server download named `cfx-server_linux_x64.tar.xz`. Do not substitute the legacy Linux master artifact named `fx.tar.xz`. As verified on 2026-09-02, the official Cfx Server Download page offers Enhanced Linux build 139 while the legacy recommended master build is 35245.

The repository pins the official Enhanced build URL and SHA-256 in `config/fxserver-linux-artifact.json`. Before changing that manifest, select **FiveM for GTAV Enhanced**, **Linux**, and the offered build on the [official Cfx Server Download page](https://docs.fivem.net/docs/server-download/), then independently verify the new checksum and archive layout.

Install the pinned archive side-by-side:

```bash
cd /opt/randy-2
git pull --ff-only origin main
PROJECT_OWNER="$(stat -c '%U' /opt/randy-2)"
sudo -u "$PROJECT_OWNER" bash scripts/install-fxserver-linux.sh
```

This creates `server-binaries/enhanced-linux-139` and refuses to overwrite it. It does not touch `runtime/qbox-server-data`, `txData`, resources, MariaDB, `.env`, or any private cfg.

Enhanced b139 txAdmin uses `TXHOST_TXA_PORT` and `TXHOST_DATA_PATH`. Do not restore the deprecated `+set txAdminPort`, `+set txDataPath`, or `+set serverProfile` launch arguments. Render and inspect the repository-owned unit before installing it:

```bash
cd /opt/randy-2
PROJECT_ROOT=/opt/randy-2 SERVICE_USER="$(stat -c '%U' /opt/randy-2)" \
  bash scripts/render-txadmin-systemd.sh /tmp/txadmin.service
grep -E '^(Environment=TXHOST_|ExecStart=)' /tmp/txadmin.service
! grep -Eq '\+set[[:space:]]+(txAdminPort|txDataPath|serverProfile)' /tmp/txadmin.service
sudo install -m 0644 /tmp/txadmin.service /etc/systemd/system/txadmin.service
rm -f /tmp/txadmin.service
sudo systemctl daemon-reload
sudo systemctl enable txadmin.service
```

This unit deliberately starts only `server-binaries/enhanced-129/run.sh`; txAdmin obtains its port and data path from `TXHOST_*`. The Linux readiness check reads `.env` as literal data (so metadata containing spaces is safe) and resolves `QBOX_RESOURCES_DIR` to the deployed runtime.

Before switching, confirm that `txadmin.service` currently refers to `/opt/randy-2/server-binaries/enhanced-129` without printing the unit contents:

```bash
sudo systemctl cat txadmin.service | grep -Fq '/opt/randy-2/server-binaries/enhanced-129'
```

Stop the service, retain the current directory under a timestamped rollback name, and put the new build behind the existing service path:

```bash
cd /opt/randy-2
NEW=/opt/randy-2/server-binaries/enhanced-linux-139
ACTIVE=/opt/randy-2/server-binaries/enhanced-129
ROLLBACK="/opt/randy-2/server-binaries/enhanced-129.rollback-$(date -u +%Y%m%dT%H%M%SZ)"

test -x "$NEW/run.sh"
test -x "$NEW/alpine/opt/cfx-server/cfx-server"
test -d "$ACTIVE"
test ! -L "$ACTIVE"

sudo systemctl stop txadmin.service
sudo mv -- "$ACTIVE" "$ROLLBACK"
sudo ln -s -- "$(basename "$NEW")" "$ACTIVE"
printf '%s\n' "$ROLLBACK" | sudo tee /opt/randy-2/runtime/last-enhanced-rollback-path >/dev/null
sudo systemctl start txadmin.service
sudo systemctl is-active --quiet txadmin.service
```

Validate txAdmin, TCP/UDP 30120, public JSON metadata, required resources, direct Enhanced-client connection, and the Cfx listing lookup. An artifact update is a diagnostic variable, not a guaranteed listing fix.

Rollback uses the saved directory and does not alter runtime data:

```bash
cd /opt/randy-2
ACTIVE=/opt/randy-2/server-binaries/enhanced-129
ROLLBACK="$(cat /opt/randy-2/runtime/last-enhanced-rollback-path)"

test -L "$ACTIVE"
test -d "$ROLLBACK"
sudo systemctl stop txadmin.service
sudo unlink -- "$ACTIVE"
sudo mv -- "$ROLLBACK" "$ACTIVE"
sudo systemctl start txadmin.service
sudo systemctl is-active --quiet txadmin.service
```
