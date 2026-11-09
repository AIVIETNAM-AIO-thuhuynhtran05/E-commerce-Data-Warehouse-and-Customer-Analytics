"""Export every mart table to Parquet for Power BI.

Run after `dbt build`. Each table in the mart schemas (core, sales, customer,
operations) is written to exports/<table>.parquet. Power BI reads the folder
with Get Data > Parquet (or Folder), so it never opens the DuckDB file and
never blocks the next dbt build.
"""

from pathlib import Path

import duckdb


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATABASE_PATH = PROJECT_ROOT / "warehouse" / "ecommerce.duckdb"
EXPORT_DIR = PROJECT_ROOT / "exports"
MART_SCHEMAS = ("core", "sales", "customer", "operations")


def main() -> None:
    if not DATABASE_PATH.exists():
        raise FileNotFoundError(f"{DATABASE_PATH} not found. Run dbt build first.")

    EXPORT_DIR.mkdir(exist_ok=True)
    with duckdb.connect(str(DATABASE_PATH), read_only=True) as connection:
        tables = connection.execute(
            """
            select table_schema, table_name
            from information_schema.tables
            where table_schema in ({})
              and table_type = 'BASE TABLE'
            order by table_schema, table_name
            """.format(", ".join("?" for _ in MART_SCHEMAS)),
            list(MART_SCHEMAS),
        ).fetchall()
        if not tables:
            raise RuntimeError("No mart tables found. Run dbt build first.")

        for schema, table in tables:
            target = EXPORT_DIR / f"{table}.parquet"
            target_sql = "'" + target.as_posix().replace("'", "''") + "'"
            connection.execute(
                f'COPY "{schema}"."{table}" TO {target_sql} (FORMAT parquet)'
            )
            row_count = connection.execute(
                f'SELECT COUNT(*) FROM "{schema}"."{table}"'
            ).fetchall()[0][0]
            print(f"Exported {schema}.{table}: {row_count:,} rows -> exports/{table}.parquet")


if __name__ == "__main__":
    main()
