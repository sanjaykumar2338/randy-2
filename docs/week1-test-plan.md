# Week 1 Acceptance Test Plan

Record results locally while testing on a supported Windows/Linux FXServer host. Do not commit logs containing credentials, player identifiers, or txAdmin secrets.

## Server

- Start MariaDB.
- Start FXServer.
- Open txAdmin.
- Start the Qbox server profile.
- Check logs for missing dependencies, manifest errors, database errors, and repeated Qbox initialization warnings.

Expected: server reaches a stable running state.

## Client

- Connect with FiveM client.
- Confirm the player joins successfully.

Expected: no critical client errors.

## Character

- Reach character creation/selection.
- Create a new character.
- Save the character.
- Load the character.

Expected: character saves and enters the game.

## Spawn

- Spawn into the standard Los Santos map.
- Confirm movement and camera control.
- Confirm player is not frozen, stuck, or invisible.

Expected: newly created character spawns safely.

## Inventory

- Open inventory using the recipe default keybind.
- Confirm inventory UI loads.
- Confirm a basic item can exist in inventory.
- Disconnect and reconnect.

Expected: inventory opens and does not reset unexpectedly.

## Money

- Check basic Qbox cash/account state.
- Make a legitimate small test change through standard framework behavior or an admin-only local test command.
- Disconnect and reconnect.

Expected: values exist, load, and persist.

## Persistence

- Create character.
- Spawn.
- Disconnect completely.
- Reconnect and select the same character.
- Restart FXServer.
- Reconnect again.

Expected: the same character still exists after reconnect and server restart.

## Voice

Only test if the standard recipe voice setup is already working without delaying core Week 1 checks.
