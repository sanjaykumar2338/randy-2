# Database

The Windows Week 1 runtime uses a standalone MariaDB installation, not XAMPP:

- Server: MariaDB 12.3.2
- Windows service: `TarrantMariaDB` (automatic)
- Listener: `127.0.0.1:3306`
- Database: `tarrant_rp_dev`
- Application user: `tarrant_rp` at `localhost` and `127.0.0.1`

The application account receives privileges only on the project database. Generated application/admin passwords live in ignored `.env`, whose local ACL is restricted; neither value should be passed on a visible command line or copied into tracked files.

## Windows Setup And Verification

Run scripts from the repository root. The per-process execution-policy bypass is needed on the current workstation:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install-mariadb.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-dev-db.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\check-env.ps1
```

`install-mariadb.ps1` requests Administrator approval, installs/configures the `TarrantMariaDB` service, restricts it to loopback, generates local credentials, creates the project database/users, and verifies the application connection. `setup-dev-db.ps1` is the narrower repeatable database/user helper for an already-supported MariaDB installation.

Check service state separately with:

```powershell
Get-Service TarrantMariaDB
```

Qbox requires MariaDB 10.9 or newer and currently recommends MariaDB 12.3 LTS for new installs. XAMPP's bundled MariaDB 10.4 is both too old and explicitly unsupported. XAMPP is retained for unrelated development, but its MySQL module must remain stopped while the standalone service owns port 3306.

The staged Qbox base, core, and vehicle schemas have already been imported into `tarrant_rp_dev`. Do not run the official Qbox txAdmin recipe against this same database: repeated seed SQL may fail or create conflicts.

## Cross-Platform/Manual Setup

For a separate supported Linux host, the Bash helper remains available:

```bash
scripts/setup-dev-db.sh
```

For reviewed manual setup, copy `database/init.example.sql` to ignored `database/init.sql`, replace its placeholder locally, and run it with an administrative MariaDB account. Never commit that generated SQL file or a private database dump.
