"""Run the whole pipeline with one command: load, transform and test, export.

    python scripts/run_pipeline.py

Steps:
1. Extract + Load: scripts/load_csvs.py loads the CSVs into DuckDB schema raw.
2. Transform + test: dbt deps (only if packages are missing), then dbt build
   (seeds, models, snapshots and every test, in DAG order).
3. Serve: scripts/export_marts.py writes the mart tables to exports/*.parquet.

The pipeline stops at the first failing step. If a dbt test fails, the
Parquet files are not rewritten, so Power BI keeps the last good data.
"""

import shutil
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import export_marts  # noqa: E402
import load_csvs  # noqa: E402


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DBT_ARGS = ["--project-dir", str(PROJECT_ROOT), "--profiles-dir", str(PROJECT_ROOT)]


def dbt_executable() -> str:
    # Prefer the dbt installed next to this Python (the project's .venv).
    scripts_dir = Path(sys.executable).parent
    for name in ("dbt.exe", "dbt"):
        if (scripts_dir / name).exists():
            return str(scripts_dir / name)
    found = shutil.which("dbt")
    if found is None:
        raise SystemExit("dbt not found. Install it with: pip install -r requirements.txt")
    return found


def run_dbt(*command: str) -> None:
    # dbt runs in its own process so its DuckDB connection is closed when it
    # exits; the export step can then open the file read-only.
    result = subprocess.run([dbt_executable(), *command, *DBT_ARGS], cwd=PROJECT_ROOT)
    if result.returncode != 0:
        raise SystemExit(f"dbt {' '.join(command)} failed. Fix the errors above and run again.")


def step(name: str, action) -> None:
    print(f"\n=== {name} ===")
    started = time.perf_counter()
    action()
    print(f"=== {name}: done in {time.perf_counter() - started:.1f}s ===")


def transform() -> None:
    if not (PROJECT_ROOT / "dbt_packages" / "dbt_utils").exists():
        run_dbt("deps")
    run_dbt("build")


def main() -> None:
    step("1/3 Extract + Load", load_csvs.main)
    step("2/3 Transform + test (dbt build)", transform)
    step("3/3 Export marts to Parquet", export_marts.main)
    print("\nPipeline finished. In Power BI Desktop, press Refresh.")


if __name__ == "__main__":
    main()
