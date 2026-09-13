# Project 07 — Glamira Data Warehouse

## 1. Project Overview

Data warehouse xây dựng bằng dbt + BigQuery cho dữ liệu bán hàng Glamira, nguồn từ MongoDB (`checkout_success` events), product catalog crawl riêng, và IP-geolocation lookup. Mục tiêu: dimensional model phục vụ phân tích doanh thu, xu hướng, sản phẩm, địa lý qua Looker Studio.

## 2. Architecture

```
raw.glamira_raw, raw.products, raw.ip_locations
              ↓
stg_glamira_raw, stg_products, stg_dim_location   (staging — view)
              ↓
7 dimensions + bridge_store_domain                (core — table)
              ↓
fact_sales_order_detail, fact_exchange_rate        (core — table/incremental)
              ↓
mart_sales_report                                  (mart — table)
              ↓
Looker Studio dashboard
```

## 3. Data Flow

- **`stg_glamira_raw`**: UNNEST `cart_products`, normalize `order_id` (strip `.0`), parse `product_price` (multi-locale: EU/US/Arabic/Swiss/JPY formats) sang `unit_price` (NUMERIC, giữ NULL khi không parse được), resolve `currency_code` (ISO) từ symbol + domain lookup (`currency_url_mapping` seed).
- **`stg_dim_location`**: đọc `raw.ip_locations`, validate và loại bỏ giá trị rác (`'IPV6 ADDRESS MISSING IN IPV4 BIN'` — 1,474 dòng phát hiện qua data quality check), sinh `location_key` sơ bộ theo geography.
- **Dimensions/facts**: build từ staging, mỗi model có Unknown Member pattern nếu cần.
- **`mart_sales_report`**: join fact với toàn bộ dimension, denormalized cho BI, loại bỏ PII (`email_address`, `ip_address` không đưa vào mart).

## 4. Data Modeling

- **Star schema, 7 dimensions + 2 fact + 1 bridge table.**
- **Fact grain**: `fact_sales_order_detail` = 1 dòng/tổ hợp `(order_id, product_id)` duy nhất — các bản ghi trùng lặp trong nguồn (do cùng sản phẩm xuất hiện nhiều lần trong 1 giỏ hàng, hoặc cùng `order_id` gán cho nhiều document checkout) được **gộp**: `SUM(order_qty)`, `SUM(order_qty × unit_price)` cho `sales_amount`, `AVG(unit_price)`.
- **Dimensions**: `dim_date` (366 rows, năm 2020), `dim_currency` (41 rows), `dim_customer` (15,107 rows, SCD2), `dim_product` (18,752 rows), `dim_store` (65 rows), `dim_location` (47,206 rows, grain = geography). `stg_dim_location` (IP → geography mapping, 3.24M rows) giữ ở tầng staging, tách riêng để không phá vỡ grain dimension.
- **Store ↔ Domain bridge**: `store_id` và `domain` có quan hệ many-to-many đã chứng minh bằng data (VD: `store 6` gắn 4 domain khác nhau, `dev1.glamira.de` gắn nhiều store). `dim_store` giữ grain 1 row/store; `bridge_store_domain` lưu quan hệ N-N riêng, không phá grain.

## 5. Key Design Decisions

- **Fact grain & duplicate aggregation**: chọn `(order_id, product_id)` sau khi bác bỏ nhiều phương án khác bằng data thật (`_id + cart_index` ban đầu đúng nhưng bị yêu cầu đổi; `order_id + product_id` một mình không unique — đã kiểm chứng có case 1 cặp trùng tới 17 lần ở nhiều document khác nhau). Quyết định cuối: gộp bằng SUM/AVG theo hướng dẫn mentor, chấp nhận đánh đổi mất chi tiết theo từng lần mua riêng lẻ.
- **SCD Type 2 (`dim_customer`)**: theo dõi lịch sử thay đổi `email_address` theo thời gian, dùng `LAG`/`PARTITION BY` để phát hiện version mới. Sentinel `end_date = '9999-12-31'` cho version hiện tại (không dùng NULL, theo yêu cầu mentor).
- **Unknown Member (`-1`)**: áp dụng cho `dim_customer`, `dim_product` — dùng khi FK không tìm thấy bản ghi tương ứng ở dimension. Không áp dụng máy móc cho mọi dimension — `dim_store` không có Unknown Member vì đã verify bằng data không có FK nào bị orphan.
- **Unresolved location geography**: `dim_location` không dùng `NULL`/`-1` riêng cho geography thiếu — mọi IP (kể cả lookup thất bại hoặc dữ liệu rác) đều resolve về 1 `location_key` hợp lệ, trong đó có 1 key đại diện cho "geography rỗng" — khác biệt kỹ thuật với Unknown Member `-1`, có chủ đích để phân biệt "không tìm thấy record" và "tìm thấy nhưng dữ liệu thiếu".
- **Currency/exchange rate**: `dim_currency` build từ 41 currency thực tế xuất hiện trong giao dịch (không hardcode ISO 4217 đầy đủ). Tỷ giá lấy từ IMF Representative Exchange Rates (31/3/2020) và BNR Romania (1/4/2020) cho các currency IMF không cover — 34/41 currency có rate, 7 currency (ARS, BOB, CRC, DOP, GTQ, PYG, VND) không tìm được nguồn tin cậy trong scope, để `NULL` thay vì tự bịa số.
- **PII masking**: BigQuery Policy Tags (column-level security) áp cho `email_address` (`dim_customer`) và `ip_address` (`stg_dim_location`, `fact_sales_order_detail`). Đã verify hoạt động thật qua service account không có quyền Fine-Grained Reader (trả về NULL đúng như thiết kế).
- **Partitioning & clustering**: `fact_sales_order_detail` partition theo `DATE(order_timestamp)`, cluster theo `(currency_key, product_key)` — chuẩn bị cho khả năng mở rộng dữ liệu.

## 6. Data Quality

- 74 dbt tests: `not_null`, `unique`, `relationships`, `dbt_utils.expression_is_true` (business logic invariants), `dbt_expectations` (range/count checks), singular tests (SCD2 invariant, business rule tổng hợp).
- Anomaly phát hiện và xử lý: `order_qty = 9999` (1 outlier, giữ nguyên trong fact), `'IPV6 ADDRESS MISSING IN IPV4 BIN'` (1,474 dòng rác trong `raw.ip_locations`, validate và chuyển NULL trong staging), price locale đa dạng (EU/US/Arabic/Swiss/JPY — 5 pattern regex xử lý, validate bằng `REGEXP_CONTAINS` trước khi `CAST`, không dùng `SAFE_CAST` mù).
- Trạng thái hiện tại: **74/74 PASS**.

## 7. Optimization

- Partition: `DATE(order_timestamp)`, verify qua `INFORMATION_SCHEMA.PARTITIONS` — dữ liệu thực sự phân bổ đúng theo từng ngày.
- Cluster: `(currency_key, product_key)`.
- Benchmark: query lọc theo 1 tháng — trước và sau khi thêm partition đều `2,827,693 bytes processed`, không giảm.
- Lý do không giảm: fact chỉ 34,776 dòng, dataset quá nhỏ để partition pruning tạo ra khác biệt đo được về `bytes processed`. Đây là tối ưu cho khả năng mở rộng tương lai, không phải cải thiện chi phí tức thời cho quy mô dữ liệu hiện tại.

## 8. Known Limitations

- Outlier `order_qty = 9999` (1 dòng): giữ nguyên trong fact theo đúng nguồn dữ liệu; có thể loại ở tầng reporting tùy mục đích phân tích cụ thể — hiện chưa có filter nào áp dụng trong `mart_sales_report`/dashboard.
- 78 dòng `sales_usd_price` NULL: 77 do 7 currency thiếu exchange rate, 1 do `unit_price` gốc NULL trong nguồn (`product_id 108669`).
- 11,643 dòng `customer_key = -1` (~35% checkout events thiếu `user_id_db`).
- 6,985 dòng `product_key = -1` (product_id không tồn tại trong `raw.products` — gap từ crawler Project 5).
- 14 dòng có `location_key` hợp lệ nhưng geography NULL/rỗng (IP lookup thất bại hoặc dữ liệu rác).
- Quy mô fact hiện tại (34,776 dòng) quá nhỏ để chứng minh lợi ích partition/cluster bằng số liệu thật.

## 9. Project Structure

```
models/
├── staging/     (view: stg_glamira_raw, stg_products, stg_dim_location, stg_store)
├── core/        (table: 7 dimensions, bridge_store_domain, fact_exchange_rate, fact_sales_order_detail)
└── mart/        (table: mart_sales_report)
seeds/           (currency_url_mapping, exchange_rate_seed)
tests/           (singular tests: SCD2 invariant, data_quality_core)
docs/            (USER_GUIDE.md)
```

## 10. How to Run

```powershell
dbt deps
dbt seed
dbt build
dbt test
dbt docs generate
dbt docs serve --port 8081
```

## 11. Output

- `mart_sales_report`: bảng denormalized cho BI, không chứa PII.
- Dashboard Looker Studio: Revenue (theo currency), Geographic (theo country), Time trends, Top Products by Revenue.
