# Ghi chú: dbt — Đưa kỹ thuật phần mềm vào SQL

> Nguồn: [Blog Anh Thư, 06/11/2026](https://aivietnam-aio-thuhuynhtran05.github.io/blog/blog/dbt-ky-thuat-phan-mem-cho-sql/)
> Minh hoạ bằng chính project này (dbt Core + DuckDB, 31 bảng nguồn, ~264k dòng).

**Ý chính:** SQL không có lỗi. Cách làm việc với SQL mới có lỗi: không quản lý phiên bản, không module hoá, không test, không tài liệu. dbt mang các thực hành kỹ thuật phần mềm vào dữ liệu.

---

## I. Vì sao có dbt

### ETL → ELT
- **ETL**: biến đổi trên máy chủ trung gian rồi mới nạp vào kho. Lý do là kho on-premise đắt.
- **ELT**: cloud warehouse và DuckDB có lưu trữ rẻ, tính toán mạnh, nên nạp dữ liệu thô trước rồi biến đổi bằng SQL ngay trong kho.
- Lợi ích: vẫn giữ dữ liệu thô. Logic sai thì chỉ chạy lại phần T, không phải extract lại từ nguồn.

### dbt là gì / không phải là gì
| dbt LÀ | dbt KHÔNG PHẢI |
|---|---|
| Trình biên dịch (SQL + Jinja → SQL thuần) | Database / engine |
| Bộ điều phối thứ tự chạy theo DAG | Công cụ Extract/Load (Fivetran, Airbyte, script Python) |
| Framework test và tài liệu | Công cụ BI, bộ lập lịch (Airflow, Dagster, cron) |

- Hiệu năng phụ thuộc vào warehouse, không phụ thuộc vào dbt.
- **Trong project:** [scripts/load_csvs.py](../scripts/load_csvs.py) làm E + L: nạp 31 file CSV vào schema `raw` của `warehouse/ecommerce.duckdb`. dbt chỉ làm T.

### Analytics Engineer
Đứng giữa Data Engineer (hạ tầng) và Data Analyst (câu hỏi kinh doanh): viết SQL nhưng làm việc với Git, code review, test, CI.

---

## II. dbt hoạt động thế nào

### Model = một câu SELECT
- Một file `.sql` chứa đúng một câu `SELECT`. Tên file thành tên bảng/view.
- dbt render Jinja (`source`/`ref` → tên thật) rồi bọc câu SELECT thành `create or replace view/table ...`.

### Các lệnh chính
| Lệnh | Tác dụng |
|---|---|
| `dbt compile` | Chỉ sinh SQL (xem trong `target/compiled/`) |
| `dbt run` | Tạo/cập nhật model |
| `dbt test` | Chạy test |
| `dbt build` | seed + run + snapshot + test theo thứ tự DAG |
| `dbt docs generate` / `serve` | Sinh website tài liệu và lineage |
| `dbt source freshness` | Kiểm tra dữ liệu nguồn có mới không |
| `dbt seed` / `dbt snapshot` / `dbt deps` | Nạp seed / chụp snapshot / cài package |

### source(), ref() và DAG
- `source('nhom', 'bang')`: trỏ tới bảng thô đã khai báo trong YAML, là điểm bắt đầu của DAG.
- `ref('model')`: trỏ tới model khác và tạo phụ thuộc. dbt tự suy ra thứ tự chạy và chạy song song khi có thể.
- `ref()` tự đổi `database.schema` theo target (`--target dev` / `prod`). Muốn tuỳ chỉnh thì dùng macro `generate_schema_name`.
- Chọn một phần DAG để chạy:
  - `dbt build -s +fact_sales`: fact_sales và mọi thứ **phía trước** nó
  - `dbt build -s stg_orders+`: stg_orders và mọi thứ **phía sau** nó

### Materialization
| Loại | Cách lưu | Dùng cho |
|---|---|---|
| `view` | Chỉ lưu câu query, tính lại mỗi lần đọc | staging, intermediate |
| `table` | Lưu kết quả, build lại toàn bộ mỗi lần | marts |
| `incremental` | Lần sau chỉ xử lý dòng mới/đổi | Bảng lớn, dữ liệu tăng dần |
| `ephemeral` | Không tạo object, chèn vào model khác dưới dạng CTE | Bước trung gian nhỏ |

- Incremental: dùng `{% if is_incremental() %}` để lọc, `{{ this }}` là bảng hiện có, bắt buộc có `unique_key`.
- **Chú ý:** incremental dễ sai nhất, hay gặp 3 lỗi:
  - Dòng đến trễ sẽ bị bỏ sót mãi. Cách phòng: lọc lùi một khoảng an toàn, ví dụ `max - 3 ngày`.
  - Thiếu `unique_key` thì dòng cập nhật bị chèn trùng.
  - Cần dựng lại từ đầu thì chạy `--full-refresh`.
- **Trong project:** `fact_sales` vẫn để `table`. Nguồn không có `updated_at` nên incremental sẽ bỏ sót đơn đổi trạng thái, mà 100k dòng thì build lại toàn bộ chỉ mất vài giây.

---

## III. Thiết kế dữ liệu

### Kiến trúc phân tầng (dữ liệu chảy một chiều)
| Tầng | Vai trò | Ví von | Materialization | Được gọi |
|---|---|---|---|---|
| **staging** | Làm sạch, 1:1 với nguồn | Nguyên liệu đã sơ chế | view | chỉ `source()` |
| **intermediate** | Join, logic, đổi grain | Các bước nấu | ephemeral / view | `ref()` staging, intermediate |
| **marts** | Fact/dim cho người dùng | Món ăn lên bàn | table / incremental | `ref()` intermediate, staging (hạn chế ref mart khác) |

- Medallion: Bronze = raw, Silver = staging (+ một phần intermediate), Gold = marts.
- Kiểm tra quy tắc phụ thuộc tự động bằng package `dbt_project_evaluator`.
- Đặt tên theo dbt Labs: `stg_<nguồn>__<thực thể>` (hai dấu gạch dưới). Quan trọng nhất là nhất quán.

**Staging**
- Nên làm: đổi tên, ép kiểu, `lower`/`trim`, đổi đơn vị (xu → đồng), `case when` đơn giản trên một cột.
- Không làm: join, group by, logic nghiệp vụ, lọc dòng theo quy tắc nghiệp vụ.
- Test tối thiểu: `unique` + `not_null` trên khoá chính.
- Staging là lớp chống sốc: nguồn đổi tên cột thì chỉ sửa một file.

**Intermediate**
- Đổi grain (gom payments về một dòng mỗi đơn), ghép nhiều nguồn thành một thực thể, định nghĩa nghiệp vụ **ở đúng một chỗ**.
- Đặt tên theo hành động: `int_orders_joined_with_payments`.
- Chỉ tạo khi logic dài, được dùng lại ở nhiều nơi, hoặc cần đổi grain trước khi join.

**Marts**
- Mỗi mart là một thực thể hoặc sự kiện nghiệp vụ, thường rộng và denormalize. Có đầy đủ test, tài liệu, contract.
- **Chú ý:** không tạo mart theo từng dashboard.

**Trong project:** 54 model = 31 staging + 5 intermediate + 18 marts (core: 8 dim + 5 fact; sales, customer, operations).

### Star schema (Kimball)
- **Fact**: sự kiện đo đếm được, chứa chỉ số và khoá ngoại.
- **Dimension**: ngữ cảnh (ai, cái gì, khi nào), dùng để lọc và nhóm.
- **Trong project:** `fact_sales` (grain: một dòng mỗi sản phẩm trong đơn) nối tới 7 dim qua surrogate key: date, customer, product, geography, promotion, shipping_method, order_status. Đơn không có mã giảm giá trỏ tới dòng `"No promotion"` (`coupon_id = -1`) thay vì `null`, nên mọi dòng fact đều join được.

### Grain và lỗi fan-out ⭐
- **Grain** = một dòng trong bảng đại diện cho cái gì.
- **Fan-out**: join quan hệ 1-n với một quan hệ 1-n khác làm số dòng bị nhân lên.
  - Ví dụ đơn #1001 có 3 sản phẩm × 2 lần thanh toán = 6 dòng. `sum(amount)` ra 900 thay vì 300.
  - SQL **không báo lỗi**, chỉ cho ra con số sai.
- Cách sửa: đưa các bảng về **cùng grain trước khi join**, ví dụ `group by order_id` cho payments.
- Trước mỗi join, tự hỏi: grain bên trái? grain bên phải? grain kết quả?
- Ghi grain vào description và đặt test `unique` trên khoá grain.
- **Trong project:** join `fact_orders` với `fact_sales` làm tổng tăng từ 10,8tr lên 40,2tr (×3,7). Xem [analyses/fanout_revenue_inflation.sql](../analyses/fanout_revenue_inflation.sql).

---

## IV. Dữ liệu đáng tin cậy

> Dữ liệu được tạo ra bằng code, mà đã là code thì phải có test.

### Data tests
- Mỗi test là một câu SELECT tìm dòng vi phạm. Trả về 0 dòng là pass.
- **Generic** (khai báo trong YAML): `unique`, `not_null`, `accepted_values`, `relationships`.
- **Singular**: file `.sql` trong `tests/`.
- Từ dbt 1.8, khoá YAML là `data_tests:` thay cho `tests:`.
- Tuỳ chọn: `severity: warn | error` và `store_failures: true` (lưu dòng lỗi vào bảng).

### Unit tests (dbt ≥ 1.8)
- Đưa dữ liệu giả vào, so với kết quả mong đợi. Dùng để kiểm tra **logic**, chạy được khi chưa có dữ liệu thật.
- Data test bắt dữ liệu bẩn, fan-out, khoá mồ côi. Unit test bắt sai công thức và trường hợp biên.

### Model contracts (dbt ≥ 1.5)
- `contract: { enforced: true }`: sai cột hoặc sai kiểu thì dbt dừng **trước khi** tạo bảng.
- Ba lớp bổ sung nhau: **unit test** bảo vệ logic, **contract** bảo vệ cấu trúc, **data test** bảo vệ dữ liệu.

**Trong project:**
- 232 data test. Lần build gần nhất: `PASS=287 WARN=1 ERROR=0 TOTAL=288` (54 model + 1 seed + 1 snapshot + 232 test).
- Có 3 singular test:
  - `assert_fact_sales_reconciles_to_orders`
  - `assert_no_revenue_from_non_revenue_statuses`
  - `warn_orders_without_items`: chỉ cảnh báo, vì có 2.258 đơn chỉ có phí ship.
- **Chưa dùng unit test và contract.** Đây là hướng mở rộng tiếp theo.

### Documentation và lineage
- Description trong YAML + DAG → `dbt docs generate && dbt docs serve`.
- Tài liệu sinh ra từ code nên luôn đúng với trạng thái hiện tại.

### CI/CD
- Mỗi PR tự chạy `dbt build` trên schema tạm. Test ở model phía sau hỏng thì PR bị chặn.
- **Slim CI** (chỉ build model thay đổi và các model phụ thuộc):
  ```bash
  dbt build --select state:modified+ --defer --state ./prod-artifacts
  ```

---

## V. Tính năng nâng cao

### Jinja và macros
| Cú pháp | Ý nghĩa |
|---|---|
| `{{ ... }}` | Biểu thức, chèn kết quả vào SQL |
| `{% ... %}` | Câu lệnh (`if`, `for`, `set`, `macro`), không chèn gì vào SQL |
| `{# ... #}` | Chú thích, bị bỏ khi compile |

- Vòng lặp dùng `loop.last` để tránh thừa dấu phẩy.
- Macro là hàm Jinja tái sử dụng, nằm trong `macros/`, theo nguyên tắc DRY.
- **Chú ý:** nếu đồng nghiệp phải compile mới đọc hiểu được thì đã dùng Jinja quá tay.
- **Trong project:**
  - `to_money(col)`: ép về `decimal(18,2)`
  - `date_key(col)`: đổi ngày thành số `YYYYMMDD`
  - `generate_schema_name`: model trong `marts/core` vào schema `core`

### Snapshots (SCD Type 2)
- Nguồn chỉ giữ giá trị hiện tại. Snapshot thêm phiên bản mới mỗi khi dữ liệu đổi, kèm cột `dbt_valid_from` / `dbt_valid_to`.
- Từ dbt 1.9 có thể khai báo bằng YAML.
- **Trong project:** [snap_products.yml](../snapshots/snap_products.yml) dùng strategy `check` trên `price, compare_at_price, is_active` (vì không có `updated_at`). `dim_product` chỉ giữ giá hiện tại (SCD1).

### Seeds, packages, exposures
- **Seeds**: CSV nhỏ trong `seeds/`, nạp bằng `dbt seed`, gọi bằng `ref()`. Chỉ dùng cho bảng tra cứu ít đổi.
  - **Trong project:** [order_status_mapping.csv](../seeds/order_status_mapping.csv) quy định trạng thái nào tính doanh thu (chỉ `paid`, `shipped`, `delivered`).
- **Packages**: khai báo trong `packages.yml`, cài bằng `dbt deps`. Ví dụ `dbt_utils` (`generate_surrogate_key`, `unique_combination_of_columns`) và `dbt_expectations`.
- **Exposures**: khai báo dashboard nào phụ thuộc model nào, để biết sửa model thì ảnh hưởng tới đâu.

---

## Bài học rút ra
1. **Grain trước, join sau.** Join sai làm doanh thu ×3,7 mà không có lỗi nào được báo.
2. **Doanh thu phải định nghĩa một lần.** Cùng một bộ dữ liệu cho ra 4 con số:
   - Tổng tiền mọi đơn: ~10,77tr
   - Các lần thanh toán thành công: ~10,06tr
   - Doanh thu thuần bất kể trạng thái: ~9,32tr
   - Doanh thu ghi nhận: ~5,49tr

   Định nghĩa đặt ở seed `order_status_mapping` + `int_orders__enriched`.
3. **Incremental là tối ưu, không phải mặc định.** Bắt đầu bằng `table`.
4. **Staging mỏng, marts rõ nghĩa.** Logic nằm ở intermediate.
5. **Test là hợp đồng, không phải thủ tục.** Mỗi test bảo vệ một giả định cụ thể.

## Mốc phiên bản cần nhớ
- dbt 1.5: model contracts
- dbt 1.8: unit tests, khoá `data_tests:`
- dbt 1.9: snapshot khai báo bằng YAML
