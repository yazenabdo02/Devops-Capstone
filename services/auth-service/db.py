import os
import sqlite3

DATABASE_URL = os.environ.get("DATABASE_URL", "")
USING_PG = DATABASE_URL.startswith("postgres")

if USING_PG:
    import psycopg2
    import psycopg2.extras

# Primary-key column type differs between the two databases.
PK = "SERIAL PRIMARY KEY" if USING_PG else "INTEGER PRIMARY KEY AUTOINCREMENT"


class Connection:
    """Thin wrapper so the same app code runs on SQLite and PostgreSQL."""

    def __init__(self, raw):
        self._raw = raw

    def _cursor(self):
        if USING_PG:
            return self._raw.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
        return self._raw.cursor()

    @staticmethod
    def _sql(sql):
        return sql.replace("?", "%s") if USING_PG else sql

    def execute(self, sql, params=()):
        cur = self._cursor()
        cur.execute(self._sql(sql), params)
        return cur

    def executemany(self, sql, seq):
        cur = self._cursor()
        cur.executemany(self._sql(sql), seq)
        return cur

    def commit(self):
        self._raw.commit()

    def close(self):
        self._raw.close()


def connect(sqlite_path):
    if USING_PG:
        return Connection(psycopg2.connect(DATABASE_URL))
    raw = sqlite3.connect(sqlite_path)
    raw.row_factory = sqlite3.Row
    return Connection(raw)
