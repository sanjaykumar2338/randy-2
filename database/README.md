# Database

Local development uses a dedicated MariaDB/MySQL database and application user:

- Database: `tarrant_rp_dev`
- User: `tarrant_rp`
- Hosts: `localhost` and `127.0.0.1`

Run the setup script from the repository root:

```bash
scripts/setup-dev-db.sh
```

The script creates `.env` if needed, generates a local database password when `DB_PASSWORD` is unset or `CHANGE_ME`, creates the database, grants privileges only on that database, and verifies the application user can connect without using `root`.

Some local MariaDB/XAMPP installs include anonymous/public grants on the default `test` schema. Those grants are outside this project user setup, but they can make `test` visible to local users. Remove them during host hardening with your preferred administrative process, such as `mysql_secure_installation` or an equivalent reviewed SQL change.

For manual setup, copy `database/init.example.sql`, replace the placeholder password locally, and run it with an administrative MariaDB/MySQL account. Do not commit modified SQL files containing real passwords.
