# Chat Escape dismissal

## Current acceptance update - 2026-10-02

**ESTABLISHED LIVE PASS (user-reported):** `tarrant_chat` is deployed on Enhanced
b156; T -> ESC immediately removes chat input/background on the tested live
client; chat reopens and works afterward. These are the operator's confirmed
results supplied for this milestone, not a new session performed by the agent.
**Randy-specific chat acceptance remains PENDING LIVE.**

The browser/Lua suite was rerun successfully on 2026-10-02 against the actual
unmodified Enhanced Linux b161 bundle, with the hashes listed below. This
verifies cancellation, incoming messages/fade, reopen/send, empty Enter/commands,
visibility preferences and theme lifecycle with stubbed FiveM natives. The
b161 `cl_chat.lua` and `dist/chat.js` hashes are identical to the previously
approved stock hashes. This is automated bundle compatibility evidence, not live
b161 client acceptance.

Use the [Randy checklist and evidence template](launch-readiness.md#operator-checklist-randy-chat-and-protected-regression).
Stop for the chat component and document any failure; do not modify the accepted
extension or stock chat automatically. No chat resource, bindings, runtime config
or VPS was changed in this milestone. No deployment or restart was performed.
The older deployment/rollback instructions below are historical runbooks and
must not be executed as part of the launch baseline acceptance milestone.

## Implementation

`tarrant_chat` uses stock chat's `chat_theme` script/stylesheet extension. It
temporarily hides `.chat-window` when Escape is released on the visible chat
textarea. The event continues to stock chat, which cancels the draft and invokes
`chatResult` to release NUI focus. It does not send callbacks, replace chat,
register keys, change `hideState`, or write character/server data.

This is intentionally separate from the bundled, generated `dist/chat.js`.
Editable upstream Vue sources are absent here. The runtime installer explicitly
removes the cloned `chat` resource so the bundled resource remains authoritative.
Do not edit artifacts/cache, add a duplicate resource named `chat`, or force
`toggleChat hidden`. A theme extension avoids maintaining a complete chat fork.

Stock chat routes both Escape and empty Enter through `hideInput(cancelled)`.
Changing that shared cancellation branch would also change empty Enter. This
extension instead observes Escape specifically, without consuming the event.
The override clears on chat open, incoming message, clear, or visibility-state
change. Stock chat then controls visibility and its normal seven-second timer.
In Visible mode, Escape temporarily dismisses history until the next such event;
in Hidden mode, incoming messages remain hidden. L and Enter are unchanged.
Theme removal cleans up the listeners and override; repeated theme injection
replaces existing listeners.

## Automated verification

Use an unmodified copy of the **actual deployed chat bundle** for each artifact
upgrade. The test serves it locally in headless Chromium, loads this resource
through `ON_UPDATE_THEMES`, and executes its real `cl_chat.lua` in a Lua harness.
FiveM natives are recorded stubs; this does not claim live engine focus testing.
No game server or player database is contacted.

```powershell
python -m pip install --target runtime/chat-test-tools playwright==1.58.0 lupa==2.6
python tests/check-chat-cancel.py --chat server-binaries/enhanced-129-test/system_resources/chat --browser 'C:/Program Files/Google/Chrome/Application/chrome.exe'
git diff --check
```

On another machine, `--chat` accepts a different bundle directory and `--browser`
accepts a Chromium executable. Python Playwright and lupa may alternatively be
installed in an isolated virtual environment.

Passed against the official Enhanced Linux b161 chat bundle (also identical to
the previously approved stock bundle for these two files):

| File | SHA-256 |
| --- | --- |
| `cl_chat.lua` | `e48050489116ef379ebbb9bc1f69522605217017287b66cef4b3c019c130c0f5` |
| `dist/chat.js` | `f192cfff13e1098cafdef1a1d8aa417592dc4a13a6c4ce0c93f17b6e85e6dd21` |

Checks cover T/release -> Escape, typed draft cancellation, incoming message
after Escape and automatic fading, reopening, message/command submission, empty
Enter, unchanged persisted modes, focus-release callback, theme reload, and
theme removal. Live b161 T -> ESC acceptance remains pending after deployment.

## Backup-first Linux deployment (operator instructions only)

No VPS deployment was performed. Choose the real paths and the full commit hash
reported with this change. `CHAT` must be the system chat resource in the active
FXServer artifact, not a cache copy. These commands refuse an unverified bundle.
If the hashes differ, copy that bundle to a test workstation, run the browser/Lua
test against it, and review its theme/DOM compatibility before deployment. Do
not bypass the check just to make deployment proceed.

First inspect the active resource list and config: exactly one `chat` should be
running, and no existing `tarrant_chat` definition should be elsewhere. Do not
run the general runtime installer on the VPS for this scoped update.

```bash
set -euo pipefail
REPO=/absolute/path/to/randy-2
DATA=/absolute/path/to/active/server-data
CHAT=/absolute/path/to/active/system_resources/chat
RELEASE=FULL_COMMIT_HASH_FROM_THIS_CHANGE
test -d "$REPO/.git"
test -f "$DATA/server.cfg"
test -f "$CHAT/fxmanifest.lua"
(
  cd "$CHAT"
  printf '%s\n' \
    'e48050489116ef379ebbb9bc1f69522605217017287b66cef4b3c019c130c0f5  cl_chat.lua' \
    'f192cfff13e1098cafdef1a1d8aa417592dc4a13a6c4ce0c93f17b6e85e6dd21  dist/chat.js' |
    sha256sum --check --strict
)
git -C "$REPO" fetch origin
git -C "$REPO" cat-file -e "$RELEASE^{commit}"

# Protect the config backup, which may contain local settings/secrets.
umask 077
BACKUP="$DATA/backups/chat-escape-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$BACKUP"
cp -a "$DATA/server.cfg" "$BACKUP/server.cfg"
TARGET="$DATA/resources/[tarrant]/tarrant_chat"
if [ -e "$TARGET" ]; then
  cp -a "$TARGET" "$BACKUP/tarrant_chat"
fi
git -C "$REPO" rev-parse "$RELEASE" > "$BACKUP/release.txt"

# Stage only this resource; leave all other runtime resources untouched.
mkdir "$BACKUP/staged"
git -C "$REPO" archive "$RELEASE" 'resources/[tarrant]/tarrant_chat' |
  tar -x -C "$BACKUP/staged"
mkdir -p "$DATA/resources/[tarrant]"
if [ -e "$TARGET" ]; then
  mv "$TARGET" "$BACKUP/replaced-tarrant_chat"
fi
cp -a "$BACKUP/staged/resources/[tarrant]/tarrant_chat" "$TARGET"
# Apply the same ownership/read permissions as the other runtime resources.
# Run as the FXServer service account, or adjust owner/group for that account.
python3 - "$DATA/server.cfg" <<'PY'
from pathlib import Path
import re
import sys
p = Path(sys.argv[1])
data = p.read_bytes()
if not re.search(rb'^\s*(?:ensure|start)\s+tarrant_chat\s*(?:[#;].*)?$', data, re.M):
    newline = b'\r\n' if b'\r\n' in data else b'\n'
    p.write_bytes(data.rstrip(b'\r\n') + newline + b'ensure tarrant_chat' + newline)
PY
printf 'Retain this rollback directory: %s\n' "$BACKUP"
```

In the authenticated **server console**, activate only the extension:

```text
refresh
ensure tarrant_chat
```

Stock chat discovers themes on resource lifecycle events (approximately 500 ms).
No restart of `chat`, other resources, or FXServer is required. Test on a client:

1. Set `toggleChat whenactive` in F8, close F8, then T -> Escape: immediate hide.
2. T -> type a draft -> Escape: draft discarded, immediate hide.
3. Confirm movement/camera and another T press work after cancellation.
4. T -> submit a test message: normal submission/history, then normal fading.
5. Receive a message after Escape: normal display and fading.
6. Test Visible/Hidden, then restore `toggleChat whenactive` (or the prior mode).

## Rollback

In the server console first run:

```text
stop tarrant_chat
```

This removes the theme and restores stock behavior for connected clients. Then
restore the exact backup, before making any later unrelated config changes:

```bash
set -euo pipefail
DATA=/absolute/path/to/active/server-data
BACKUP=/absolute/path/to/the/retained/chat-escape-backup
test -f "$BACKUP/server.cfg"
TARGET="$DATA/resources/[tarrant]/tarrant_chat"
cp -a "$BACKUP/server.cfg" "$DATA/server.cfg"
if [ -e "$TARGET" ]; then
  mv "$TARGET" "$BACKUP/rolled-back-tarrant_chat-$(date -u +%Y%m%dT%H%M%SZ)"
fi
if [ -d "$BACKUP/tarrant_chat" ]; then
  cp -a "$BACKUP/tarrant_chat" "$TARGET"
fi
```

Run `refresh` in the server console. Only if a previous `tarrant_chat` installation
was restored and previously enabled, run `ensure tarrant_chat` again. Otherwise
leave it stopped. No bundled chat files, database, or user bindings need restoring.
