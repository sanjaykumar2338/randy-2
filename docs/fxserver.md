# FXServer Development Notes

FXServer server binaries are intentionally not stored in this repository. Keep downloaded artifacts and txAdmin runtime data outside Git, then point the server at this repository as the server-data/config workspace.

The official Cfx.re setup references are:

- [Setting up a FiveM Server](https://docs.fivem.net/docs/getting-started/setup-fivem-server/)
- [Setting Up a Vanilla FXServer](https://docs.fivem.net/docs/server-manual/setting-up-a-server-vanilla/)
- [Windows artifacts](https://runtime.fivem.net/artifacts/fivem/build_server_windows/master/)
- [Linux artifacts](https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/)

The official setup flow is:

1. Download the latest recommended FiveM server artifact from the official Server Download page.
2. Extract the artifact into a dedicated binary directory outside the repository.
3. Start FXServer and use bundled txAdmin at `http://localhost:40120`.
4. Link a Cfx.re account and enter a development license key in local, ignored config.

This workstation is macOS ARM64. Cfx.re documents FXServer setup paths for Windows and Linux, but not native macOS, so FXServer was not installed or started here.

Suggested local layout on a supported host:

```text
~/FXServer/
  server/       # downloaded artifacts, not committed
  txData/       # txAdmin runtime data, not committed
  server-data/  # clone of this repository
```

Linux example:

```bash
cd ~/FXServer/server-data
bash ~/FXServer/server/run.sh +exec config/server.cfg
```

Windows example:

```powershell
cd C:\FXServer\server-data
C:\FXServer\server\FXServer.exe +exec config\server.cfg
```

For first-run txAdmin setup, start FXServer without `+exec config/server.cfg`, then complete the browser setup and keep generated secrets out of Git.
