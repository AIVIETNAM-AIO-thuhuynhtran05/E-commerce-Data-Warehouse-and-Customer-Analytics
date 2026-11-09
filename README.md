# E-commerce Data Warehouse & Customer Analytics

A data-engineering portfolio project that turns 31 raw e-commerce CSV files into
a tested **star schema for sales analytics**, built with **dbt Core and DuckDB**
and organised in three layers: staging → intermediate → marts.

## Project at a glance

| | |
|---|---|
| Source | 31 generated CSV tables, ~264K rows (7K customers, 36K orders, 100K order items, 2021–2025) |
| Models | 54 (31 staging, 5 intermediate, 8 dimensions, 5 core facts, 5 marts) |
| Tests | 236 data tests: keys, relationships, accepted values, and business-rule tests |
| Other dbt features | seed, snapshot (SCD2), macros, `dbt_utils`, analyses |
| Warehouse | DuckDB (local file) |

## Architecture

```text
31 CSV files
    │  scripts/load_csvs.py                      (Extract + Load)
    ▼
DuckDB  raw.*
    │
    ▼  dbt                                        (Transform)
staging        31 views   rename, cast, clean, drop password_hash — one model per source table
    │
    ▼
intermediate    5 views   joins, order-grain rollups, business rules (revenue definition)
    │
    ▼
marts          18 tables
    ├── core        star schema: 8 dimensions + 5 facts
    ├── sales       mart_sales_daily, mart_product_performance
    ├── customer    mart_customer_360 (RFM segments)
    └── operations  fact_inventory_current, fact_support_tickets
```

### What each layer does

| Layer | Question it answers | Rules |
|---|---|---|
| **Staging** | What is in the source? | 1:1 with source tables. Rename keys (`id` → `order_id`), cast types (money → `decimal(18,2)`), normalise text, drop `password_hash`. No joins. |
| **Intermediate** | How do the tables fit together? | Joins and rollups reused by several marts. Business rules are defined **once** here, e.g. which order statuses count as revenue. |
| **Marts** | What do analysts need? | Facts and dimensions with surrogate keys and documented grains. Materialised as tables. |

## Star schema

`fact_sales` is the central fact at **order-item grain**. Each foreign key points
to a dimension built with `dbt_utils.generate_surrogate_key`.

```mermaid
erDiagram
    fact_sales }o--|| dim_date : order_date_key
    fact_sales }o--|| dim_customer : customer_key
    fact_sales }o--|| dim_product : product_key
    fact_sales }o--|| dim_geography : ship_to_geography_key
    fact_sales }o--|| dim_promotion : promotion_key
    fact_sales }o--|| dim_shipping_method : shipping_method_key
    fact_sales }o--|| dim_order_status : order_status_key

    fact_sales {
        string order_item_id PK
        string order_id "degenerate dimension"
        int quantity
        decimal gross_amount
        decimal discount_amount
        decimal net_amount
        decimal tax_amount
        decimal recognized_revenue
        int refunded_quantity
        decimal refunded_amount
    }
    dim_date {
        int date_key PK
        date date_day
        int year
        int quarter
        string year_month
        bool is_weekend
    }
    dim_customer {
        string customer_key PK
        int customer_id
        date signup_date
        date first_order_cohort_month
    }
    dim_product {
        string product_key PK
        string sku
        string category_name
        string brand_name
        decimal current_price
    }
    dim_geography {
        string geography_key PK
        string state_province
        string city
        string postal_code
    }
    dim_promotion {
        string promotion_key PK
        string coupon_code
        decimal discount_value
    }
    dim_order_status {
        string order_status_key PK
        string status_name
        bool counts_as_revenue
    }
```

Other facts keep their own grain and share the same (conformed) dimensions:

| Fact | Grain | Use for |
|---|---|---|
| `fact_sales` | order item | revenue, units, discounts by product / category / date / location |
| `fact_orders` | order | order counts, AOV, shipping cost, order totals |
| `fact_payments` | payment transaction | payment method mix, failed / refunded payments |
| `fact_shipments` | shipment | days to ship, transit time, on-time delivery |
| `fact_returns` | return request | return reasons and refund amounts |

## Design decisions

**1. Sum each measure only at its own grain.** `order_total` is an order-level
amount. Joining `fact_orders` to `fact_sales` and summing it repeats each order
once per line: the total grows from 10.8M to 40.2M (3.7×) with no error. See
[`analyses/fanout_revenue_inflation.sql`](analyses/fanout_revenue_inflation.sql).

**2. One revenue definition.** The same data gives very different "revenue":

| Definition | Amount |
|---|---|
| All order totals, any status | 10.77M |
| Completed payments | 10.06M |
| Net sales, any status (before tax and shipping) | 9.32M |
| **Recognized revenue** (paid, shipped, delivered; before tax and shipping) | **5.49M** |

Which statuses count is a business rule kept in the
[`order_status_mapping`](seeds/order_status_mapping.csv) seed and applied once in
`int_orders__enriched`. See [`analyses/revenue_definitions.sql`](analyses/revenue_definitions.sql).

**3. Order discounts are allocated to lines.** The source only has discounts at
order level (line discounts are always 0). `int_order_items__enriched` spreads
each order discount across its lines by gross amount, so `net_amount` in
`fact_sales` is correct at any level of aggregation. A singular test checks that
lines add back up to the order header.

**4. "No promotion" row instead of null keys.** Orders without a coupon point to
a `coupon_id = -1` row in `dim_promotion`, so every fact row joins to every
dimension.

**5. Geography is a location, not a person.** `dim_geography` keeps country,
state, city and postal code, not street addresses. In this generated data the
ship-to address usually belongs to another user, so geography is modelled as the
ship-to location of the order rather than an attribute of the customer.

**6. No incremental models yet.** Orders change status after they are created,
but the source has no `updated_at` column, so an incremental filter would miss
those changes. At 100K rows a full rebuild takes seconds.

**7. Revenue follows the order status, not the payments table.** An order counts
as revenue when its status is paid, shipped or delivered, whether or not a
completed payment exists. 1,429 such orders have no completed payment (993 paid,
210 shipped, 226 delivered) and are still counted. This is an assumption set for
this project: in a real company, whether the order status or the payment record
is the source of truth is a rule to agree with finance. The
`warn_revenue_orders_without_completed_payment` test reports these orders on
every build.

**8. Refunds equal what the customer paid.** A refund is valued at the net unit
price of the line (after its share of the order discount), times the returned
quantity. It excludes tax and shipping, the same basis as recognized revenue, so
`recognized_revenue - refunded_amount` never goes below zero for a line. Valuing
refunds at list price would overstate 296 discounted returns, by about 1,750 in
total. This is also an assumption set for this project: real refund policies
(tax, shipping, clawing back a coupon when a return drops the order below its
minimum) are decided by finance.

**9. Customer value is measured on billed order totals.** Two columns share the
word "revenue" on purpose, at different grains:

| Column | Grain | Basis | Total |
|---|---|---|---|
| `fact_sales.recognized_revenue` | order item | after discount, before tax and shipping | 5.49M |
| `mart_customer_360.lifetime_revenue` | customer | full `order_total`, including tax and shipping | 6.35M |

Both count only paid, shipped and delivered orders. The 0.86M gap is exactly tax
(0.44M) plus shipping (0.42M). Sales reporting uses recognized revenue;
customer value (lifetime revenue, average order value, RFM monetary score) uses
what the customer was billed. In a BI tool, label them differently, for example
"Revenue" and "Customer billed value", so the two totals are not compared as if
they were the same measure.

**10. RFM scoring: common practice and the choices made here.** RFM segments
customers by Recency (days since the last purchase), Frequency (number of
orders) and Monetary value. Each is scored 1 to 5 and R × F is mapped to named
segments.

| Choice | Common business practice | This project | Why it fits this data |
|---|---|---|---|
| Observation window | Last 12 or 24 months, so old activity does not inflate scores | Full history, 2021 to 2025 | The data is generated, with no real purchase cycle to anchor a window. A 24-month window would drop 1,294 of 6,234 revenue customers from scoring. |
| Reference date ("today") | Date the report runs | Last order date in the data (2025-12-31) | The data is historical; using the real date would make every customer look lapsed. |
| Monetary basis | Net revenue: after discount and refunds, excluding tax and shipping | Billed order total of revenue orders, including tax and shipping | Same basis as `lifetime_revenue` (decision 9). Switching to net revenue is a one-line change if the business prefers it. |
| Frequency score | Fixed thresholds set with the business, stable month to month | Fixed thresholds: 1, 2, 3–4, 5–7, 8+ orders | Order counts are small and discrete: 1,551 customers have 1 order, 1,504 have 2, 1,200 have 3. Each low count gets its own score. |
| Recency and monetary scores | Fixed thresholds or percentile cut-offs | Percentile cut-offs at 20/40/60/80% | No business thresholds exist for generated data; percentiles give five groups of about 1,250 customers each. |
| Segments | 8 to 11 named cells on an R × F grid, M used to prioritise inside a cell | 6 segments plus "No revenue orders" | Enough to show the method; finer segments such as "Can't lose them" can be added later. |

The first version used `ntile(5)`, which splits customers into equal-sized
groups regardless of ties: customers with the same single order got either
score 1 or 2, and segment counts changed between builds of the same data
(Champions went from 1,387 to 1,687). The current scores are deterministic, and
`assert_rfm_scores_are_consistent` fails if equal inputs ever get different
scores. Current segments: Hibernating 1,809, Recent 1,619, Needs attention
1,002, Champions 881, No revenue orders 766, At risk 569, Loyal 354.

## Data quality

- Primary keys: `unique` + `not_null` on every source, staging model, dimension and fact.
- Foreign keys: `relationships` tests from every fact key to its dimension.
- Categorical columns: `accepted_values` on statuses, priorities and RFM segments.
- Business rules (`tests/`):
  - `assert_fact_sales_reconciles_to_orders`: line gross and allocated discounts equal the order header.
  - `assert_no_revenue_from_non_revenue_statuses`: pending, cancelled and refunded orders add no revenue.
  - `warn_orders_without_items` (**warning**): 2,258 orders have no items (subtotal 0, total = shipping). Reported on every build without blocking it.
  - `assert_refund_not_above_amount_paid` and `assert_return_not_above_amount_paid`: no refund or return is worth more than the customer paid for the line.
  - `assert_rfm_scores_are_consistent`: customers with the same recency, order count or lifetime revenue get the same RFM score.
  - `warn_revenue_orders_without_completed_payment` (**warning**): 1,429 orders counted as revenue have no completed payment. See design decision 7.

## Jinja in this project

[Jinja](https://jinja.palletsprojects.com/) is a Python templating language. dbt
treats every model as a Jinja template: `dbt compile` renders it into plain SQL,
and only that SQL is sent to DuckDB. This adds variables, conditions, loops and
reusable functions to SQL, which has none of these on its own.

| Syntax | Meaning | Example |
|---|---|---|
| `{{ ... }}` | Expression: its result is written into the SQL | `{{ ref('stg_ecommerce__orders') }}` |
| `{% ... %}` | Statement: `if`, `for`, `set`, `macro`; writes nothing by itself | `{% macro to_money(column_name) %}` |
| `{# ... #}` | Comment, removed at compile time | `{# Cast a numeric column... #}` |

A model before and after compilation (simplified from `stg_ecommerce__orders`;
the full compiled SQL is in `target/compiled/ecommerce_analytics/models/`):

```sql
-- written
select {{ to_money('total') }} as order_total
from {{ source('ecommerce_raw', 'orders') }}

-- compiled
select cast(total as decimal(18, 2)) as order_total
from "ecommerce"."raw"."orders"
```

Where the project uses Jinja:

| Use | Where |
|---|---|
| `source()` and `ref()`: resolve table names and build the DAG | every model |
| Custom macros | `macros/to_money.sql`, `macros/date_key.sql`, `macros/generate_schema_name.sql` |
| Package macros | `dbt_utils.generate_surrogate_key` for dimension keys |
| Project variables | `var('calendar_start_date')` and `var('calendar_end_date')` in `dim_date` |

Macros are kept small and single-purpose so that a model can still be read
without compiling it.

## Project structure

```text
dbt/
├── README.md
├── dbt_project.yml              project config: folders, materializations, schemas, vars
├── profiles.yml                 connection to the local DuckDB file
├── packages.yml                 dbt packages (dbt_utils)
├── package-lock.yml             pinned package versions
├── requirements.txt             Python dependencies (dbt-duckdb)
├── .gitignore
│
├── data/raw/ecommerce_100k/     31 source CSV files                    ┐ Extract
├── scripts/load_csvs.py         loads the CSVs into DuckDB schema raw  ┘ + Load
├── warehouse/                   ecommerce.duckdb is created here (not committed)
│
├── models/                                                              ┐
│   ├── staging/ecommerce/       31 views: clean each source table       │
│   ├── intermediate/            5 views: joins and business rules       │ Transform
│   └── marts/                   18 tables: star schema and marts        │ (dbt)
│       ├── core/  sales/  customer/  operations/                        │
├── seeds/                       business-rule lookup (CSV)              │
├── snapshots/                   SCD2 price history                      │
├── macros/                      reusable SQL snippets                   ┘
│
├── tests/                       singular business-rule tests
└── analyses/                    one-off queries that explain design choices
```

Each folder under `models/` is built into the DuckDB schema of the same name:
`staging`, `intermediate`, `core`, `sales`, `customer`, `operations`, plus
`seeds` and `snapshots`. Source tables stay in `raw`.

### Root files

| File | Purpose |
|---|---|
| `dbt_project.yml` | Project name, folder paths, materialization per layer (staging and intermediate as views, marts as tables), target schema per folder, and the `dim_date` calendar range (`vars`). |
| `profiles.yml` | dbt connection profile. Points to `warehouse/ecommerce.duckdb`. Local only, no credentials. |
| `packages.yml` / `package-lock.yml` | Declares and pins `dbt_utils` (used for surrogate keys). Installed by `dbt deps` into `dbt_packages/`. |
| `requirements.txt` | Python packages: `dbt-duckdb`, which also installs dbt Core and DuckDB. |

### Extract and load

| File | Purpose |
|---|---|
| `data/raw/ecommerce_100k/*.csv` | 31 generated source tables (orders, order_items, users, products, payments, ...). |
| `scripts/load_csvs.py` | Creates schema `raw` in DuckDB and loads every CSV into a table of the same name (`orders.csv` → `raw.orders`). dbt only reads these tables, never the CSVs. |

### `models/staging/ecommerce/`: clean the source

One view per source table. Rename, cast and clean only: no joins, no filters, no business rules.

| File | Purpose |
|---|---|
| `_ecommerce__sources.yml` | Declares the 31 tables in schema `raw` as source `ecommerce_raw`, with a description and `not_null` / `unique` tests on `id`. Models read them with `{{ source('ecommerce_raw', '<table>') }}`. |
| `_ecommerce__models.yml` | Documents the 31 staging models and tests them: primary keys after renaming (`order_id`, `customer_id`, ...) and `accepted_values` on statuses and other categorical columns. |
| `stg_ecommerce__<table>.sql` (×31) | Renames keys (`id` → `order_id`, `user_id` → `customer_id`), casts money to `decimal(18,2)` and dates to `timestamp`, trims and lowercases text, drops `password_hash`. |

### `models/intermediate/`: join and apply business rules

Logic reused by several marts lives here, so it is written once.

| File | Purpose |
|---|---|
| `_int__models.yml` | Documentation and tests for the intermediate models. |
| `int_orders__enriched.sql` | One row per order. Joins status, the `order_status_mapping` seed, item counts and payments. **The only place that decides whether an order counts as revenue.** |
| `int_order_items__enriched.sql` | One row per order item. Adds order context, allocates the order-level discount to lines by gross amount, attaches refunded returns. |
| `int_orders__payments_agg.sql` | Payments rolled up to one row per order, so they can be joined to orders without duplicating rows. |
| `int_customers__order_history.sql` | One row per customer with orders: first / last order, order count, revenue. |
| `int_addresses__geography.sql` | Maps each address to a location (country, state, city, postal code) and its `geography_key`. Street details are dropped. |

### `models/marts/`: tables for analysis

**`core/`**: the star schema. Dimensions and facts with surrogate keys and documented grains.

| File | Purpose |
|---|---|
| `_core__models.yml` | Documentation and tests: primary keys, `relationships` from every fact key to its dimension. |
| `dim_date.sql` | Calendar, one row per day, range from `vars` in `dbt_project.yml`. |
| `dim_customer.sql` | Customers with signup date and first-order cohort. |
| `dim_product.sql` | Current product attributes with category and brand (SCD1; price history is in `snap_products`). |
| `dim_geography.sql` | Ship-to locations. |
| `dim_promotion.sql` | Discount coupons plus a "No promotion" row (`coupon_id = -1`). |
| `dim_order_status.sql` | Order statuses with `counts_as_revenue` from the seed. |
| `dim_payment_method.sql`, `dim_shipping_method.sql` | Lookup dimensions. |
| `fact_sales.sql` | **Central fact**, one row per order item: quantity, gross, discount, net, tax, recognized revenue, refunds. |
| `fact_orders.sql` | One row per order: order-level amounts (shipping, tax, total) that cannot be split across items. |
| `fact_payments.sql` | One row per payment transaction. |
| `fact_shipments.sql` | One row per shipment: days to ship, transit time, on-time delivery. |
| `fact_returns.sql` | One row per return request: reason and refund amount. |

**`sales/`, `customer/`, `operations/`**: pre-aggregated tables built on top of `core/`.

| File | Purpose |
|---|---|
| `sales/mart_sales_daily.sql` | One row per order date and product category: daily sales trend. |
| `sales/mart_product_performance.sql` | One row per product: units, revenue, returns, reviews. |
| `customer/mart_customer_360.sql` | One row per customer: lifetime metrics and RFM segment. |
| `operations/fact_inventory_current.sql` | Current stock by product and warehouse. |
| `operations/fact_support_tickets.sql` | One row per support ticket: priority, status, message counts, hours to first agent reply. |
| `_sales__models.yml`, `_customer__models.yml`, `_operations__models.yml` | Documentation and tests for each folder. |

### Other dbt folders

| File | Purpose |
|---|---|
| `seeds/order_status_mapping.csv` | Business rule as data: for each order status, its fulfillment stage and whether it `counts_as_revenue`. Loaded by `dbt seed`. |
| `seeds/_seeds.yml` | Column types and tests for the seed. |
| `snapshots/snap_products.yml` | SCD type 2 snapshot of product price and status (`check` strategy). Each `dbt snapshot` run opens a new version when price or status changes. |
| `macros/to_money.sql` | `to_money(col)` → `cast(col as decimal(18,2))`. |
| `macros/date_key.sql` | `date_key(col)` → integer `YYYYMMDD`, matching `dim_date.date_key`. |
| `macros/generate_schema_name.sql` | Uses the folder schema name as-is (`core`, not dbt's default `analytics_core`). |
| `tests/assert_fact_sales_reconciles_to_orders.sql` | Line gross and allocated discounts must add up to the order header. |
| `tests/assert_no_revenue_from_non_revenue_statuses.sql` | Pending, cancelled and refunded orders must have zero recognized revenue. |
| `tests/warn_orders_without_items.sql` | Warning only: reports orders that have no items. |
| `analyses/fanout_revenue_inflation.sql` | Shows how joining order-level amounts to item grain inflates totals. Compiled, not built. |
| `analyses/revenue_definitions.sql` | Compares four definitions of "revenue" on the same data. |

### Generated, not committed

| Path | Created by |
|---|---|
| `warehouse/ecommerce.duckdb` | `scripts/load_csvs.py` and `dbt build` |
| `target/` | Every dbt command: compiled SQL, `manifest.json`, docs site |
| `dbt_packages/` | `dbt deps` |
| `logs/` | dbt run logs |
| `.venv/` | Python virtual environment |

## Run locally

Requirements: Python 3.9+.

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
python scripts\load_csvs.py          # load CSVs into warehouse/ecommerce.duckdb
dbt deps --profiles-dir .            # install dbt_utils
dbt build --profiles-dir .           # seed, run, snapshot and test everything
dbt docs generate --profiles-dir .   # then: dbt docs serve --profiles-dir .
```

`profiles.yml` holds a local DuckDB profile only; do not put credentials in it.

## Limitations and next steps

- Data is generated: some relationships are random (ship-to addresses, all
  categories top level, one country), so results show the method, not real
  business insight.
- Inventory is current state only; schedule `snap_products`-style snapshots of
  inventory to analyse stock over time.
- Add a BI layer (Power BI) on the star schema for sales trends, cohorts and returns.
