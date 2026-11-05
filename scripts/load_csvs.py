from pathlib import Path
import re

import duckdb


PROJECT_ROOT = Path(__file__).resolve().parents[1]
CSV_DIR = PROJECT_ROOT / "data" / "raw" / "ecommerce_100k"
DATABASE_PATH = PROJECT_ROOT / "warehouse" / "ecommerce.duckdb"


def quote_identifier(value: str) -> str:
    if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", value):
        raise ValueError(f"Unexpected table identifier: {value}")
    return f'"{value}"'


def sql_string(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def main() -> None:
    csv_files = sorted(CSV_DIR.glob("*.csv"))
    if not csv_files:
        raise FileNotFoundError(f"No CSV files found in {CSV_DIR}")

    DATABASE_PATH.parent.mkdir(parents=True, exist_ok=True)
    with duckdb.connect(str(DATABASE_PATH)) as connection:
        connection.execute("CREATE SCHEMA IF NOT EXISTS raw")
        for csv_file in csv_files:
            table = quote_identifier(csv_file.stem)
            csv_path = sql_string(csv_file.resolve().as_posix())
            connection.execute(
                f"CREATE OR REPLACE TABLE raw.{table} "
                f"AS SELECT * FROM read_csv_auto({csv_path}, header = true)"
            )
            row_count = connection.execute(
                f"SELECT COUNT(*) FROM raw.{table}"
            ).fetchone()[0]
            print(f"Loaded raw.{csv_file.stem}: {row_count:,} rows")

    print(f"Loaded {len(csv_files)} CSV files into {DATABASE_PATH}")


if __name__ == "__main__":
    main()
