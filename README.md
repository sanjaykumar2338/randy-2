# Tarrant RP

Commercial FiveM lifestyle/economy RP server foundation for a future Qbox installation.

This repository currently contains local development structure, configuration templates, database setup helpers, and security hygiene only. Qbox and gameplay systems are intentionally not installed yet.

## Structure

```text
config/             Example FXServer config files
database/           Local database setup documentation and SQL template
docs/               FXServer platform/setup notes
resources/[tarrant]/ Project-specific future custom resources
scripts/            Repeatable local development checks/setup
```

## Prerequisites

- Git
- MariaDB or MySQL
- Node.js/npm for future framework and resource tooling
- A Cfx.re account and development server license key
- A supported FXServer host: Windows or Linux
- Latest recommended FiveM FXServer artifact from the official Cfx.re Server Download page

This workstation is macOS ARM64. Use it for repository and database preparation, but run FXServer itself on Windows or Linux.

## First-Time Setup

1. Clone this repository.
2. Copy `.env.example` to `.env`, or run `scripts/setup-dev-db.sh` to create it with a generated local DB password.
3. Create the local database and dedicated application user:

```bash
scripts/setup-dev-db.sh
```

4. Copy `config/server.example.cfg` to an ignored local config such as `config/server.cfg`.
5. Copy `config/development.example.cfg` to `config/development.cfg` and replace placeholder local values.
6. Add a Cfx.re development license key only to ignored local config.
7. Download the latest recommended FXServer artifact on a supported Windows/Linux host and keep binaries outside this repository.
8. Start FXServer/txAdmin from the supported host and point it at this server-data repository.
9. Verify local dependencies and database connectivity:

```bash
scripts/check-env.sh
```

## FXServer

See `docs/fxserver.md` for official Cfx.re links, platform notes, and startup examples. Do not commit downloaded FXServer artifacts, txAdmin runtime data, cache, or logs.

## Database

Default local development database settings:

- Database: `tarrant_rp_dev`
- User: `tarrant_rp`
- Host: `127.0.0.1` / `localhost`

The application user receives privileges only on the project database.

## Security

Real secrets stay in ignored local files such as `.env`, `server.cfg`, `config/server.cfg`, `config/development.cfg`, and `secrets.cfg`.

Never commit:

- Cfx.re license keys
- Database passwords
- Discord credentials
- Tebex secrets
- Production IPs/passwords
- Private database exports
- FXServer binaries or generated runtime data

Use example files in Git plus local secret files outside Git.
