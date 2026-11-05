# E-commerce Data Warehouse & Customer Analytics

A portfolio data-engineering project that turns a generated e-commerce dataset
into tested analytics models with **dbt Core and DuckDB**. It covers the full
workflow from local CSV ingestion through staging and intermediate transformations
to sales, customer, and operations marts.

## Project at a glance

- **31 source tables** and approximately **264K source rows**
- **44 dbt models** across staging, intermediate, and marts
- **92 data tests** for source keys, mart keys, and selected relationships
- **DuckDB** for a lightweight, local warehouse

## Architecture

```text
31 generated CSV files
        |
        v
Python loader -----> DuckDB raw schema
                           |
                           v
                  staging (31 views)
                           |
                           v
             intermediate (reusable logic)
                           |
                           v
             marts (analytics-ready tables)
               /          |           \
             sales     customer     operations
```

### dbt layers

| Layer | Purpose | Examples |
|---|---|---|
| Staging | One source-aligned model per CSV; keep transformations thin | `stg_ecommerce__orders`, `stg_ecommerce__products` |
| Intermediate | Reusable business logic and joins | `int_order_items_enriched` |
| Marts | Facts and dimensions designed for analytics | `fact_order_items`, `dim_customer`, `mart_customer_360` |

### Analytics models

**Core sales schema**

- `fact_order_items` — one row per order item; the primary grain for product and
  line-level sales analysis.
- `fact_orders` — one row per order; order subtotal, discount, tax, shipping,
  and total.
- `fact_payments` — one row per payment transaction.
- `fact_shipments` — one row per shipment.
- `fact_returns` — one row per return record.
- `dim_customer`, `dim_product`, `dim_order_status`, and `dim_date`.

**Customer mart**

- `mart_customer_360` — one row per customer with order and review summaries.

**Operations marts**

- `fact_support_tickets` — one row per support ticket.
- `fact_inventory_current` — one row per inventory record and warehouse.

Facts retain their own grains. For example, joining payments or shipments
directly to order items can multiply rows and inflate sales. Aggregate each
fact to a shared grain before combining measures.

## Metric definitions and caveats

- `gross_line_amount` is quantity multiplied by unit price.
- `net_line_amount` is gross line amount less the line discount, before tax and
  shipping.
- `fact_orders.total` is an order-level amount. Do not sum it after joining to
  order-item grain.
- `mart_customer_360.lifetime_order_value` sums source order totals across all
  order statuses; it is **not** a paid-revenue metric.
- Inventory is a current-state source, not a historical snapshot. The dataset
  cannot support inventory trends over time without periodic snapshots.
- The source CSVs are generated sample data. The local DuckDB database and dbt
  build artifacts are not committed.

## Dataset coverage

The 31 CSV tables cover customers and addresses; catalog, brands, categories,
attributes, and inventory; carts and wishlists; orders, items, payments,
shipments, coupons, and returns; reviews; support tickets and messages; and
reference data such as countries, tax rates, and shipping methods.

## Run locally

Requirements: Python 3.9 or later and PowerShell on Windows.

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
python scripts\load_csvs.py
dbt debug --profiles-dir .
dbt build --profiles-dir .
```

The loader reads `data/raw/ecommerce_100k/*.csv` and creates/replaces tables in
the DuckDB `raw` schema. The local database is written to
`warehouse/ecommerce.duckdb`. `profiles.yml` contains a local demo profile; do
not put production credentials in it.

## Repository layout

```text
data/raw/ecommerce_100k/       Generated source CSVs
scripts/load_csvs.py           CSV-to-DuckDB loader
models/staging/ecommerce/      Source declarations and staging models
models/intermediate/           Reusable transformations
models/marts/core/             Shared dimensions and core facts
models/marts/customer/         Customer analytics
models/marts/operations/       Inventory and support analytics
models/marts/schema.yml        Model documentation and data tests
dbt_project.yml                dbt project configuration
profiles.yml                   Local DuckDB profile
```

## Next steps

- Add explicit source-specific type casts and column descriptions to staging.
- Add a paid-revenue definition after agreeing on order and payment status rules.
- Snapshot inventory regularly if historical stock analysis is required.
- Add BI dashboards for sales trends, customer cohorts, returns, and fulfillment.
