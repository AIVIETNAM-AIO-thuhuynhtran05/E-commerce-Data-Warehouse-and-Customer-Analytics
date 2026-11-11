# Kiểm tra bốn hướng phân tích sản phẩm

Trang Power BI "Doanh thu sản phẩm" hiện có doanh thu, số lượng bán và tỷ lệ hoàn theo danh mục, thương hiệu, sản phẩm. Trước khi thêm biểu đồ mới, project kiểm tra bốn hướng phân tích sản phẩm thường gặp để xem dữ liệu có đủ tín hiệu không. Cả bốn hướng đều không đủ, nên không được đưa vào dashboard. Report này ghi lại cách kiểm tra, số liệu và lý do.

Dữ liệu dùng để kiểm tra: 400 sản phẩm, 36.000 đơn hàng (33.742 đơn có dòng sản phẩm), 100.000 dòng đơn, 6.000 review, giai đoạn 2021–2025. Dữ liệu do bộ sinh dữ liệu tạo ra.

Các truy vấn nằm trong `analyses/` và chạy lại được:

```powershell
dbt compile --profiles-dir . -s product_check_rating product_check_basket product_check_price product_check_launch
```

rồi chạy file đã biên dịch trong `target/compiled/ecommerce_analytics/analyses/` trên `warehouse/ecommerce.duckdb`.

## Tóm tắt

| Hướng phân tích | Kết quả | File |
|---|---|---|
| Rating so với doanh thu | Không có quan hệ (hệ số tương quan −0,03). Chỉ 13,4% review do người đã mua sản phẩm đó viết. | `product_check_rating.sql` |
| Sản phẩm hay được mua cùng | Kết quả trên dữ liệu thật gần như giống trên dữ liệu đã xáo trộn ngẫu nhiên. | `product_check_basket.sql` |
| Ảnh hưởng của giá và giảm giá | Cả 400 sản phẩm chỉ có một mức giá trong 5 năm. Dòng có giảm giá và không giảm giá có cùng số lượng mua. | `product_check_price.sql` |
| Doanh số kể từ khi ra mắt | 21,1% dòng bán hàng có ngày đặt trước ngày tạo sản phẩm, nên `created_at` không phải ngày ra mắt. | `product_check_launch.sql` |

## 1. Rating so với doanh thu

Câu hỏi: sản phẩm được đánh giá cao có bán chạy hơn, hoặc ít bị hoàn hơn không?

| Chỉ số (400 sản phẩm) | Giá trị |
|---|---|
| Tương quan Pearson: rating trung bình và doanh thu | −0,029 |
| Tương quan Spearman (theo thứ hạng): rating và doanh thu | −0,053 |
| Tương quan Pearson: rating và tỷ lệ hoàn | −0,087 |
| Tương quan Pearson: số review và số lượng bán | 0,979 |

Hai hệ số đầu gần 0, nên rating không liên quan đến doanh thu. Hệ số cuối gần 1 chỉ cho biết số review tăng theo số lượng bán: trung bình mỗi sản phẩm có 3,65 review trên 100 sản phẩm bán ra, độ lệch chuẩn 1,17. Đây là cách bộ sinh dữ liệu phân bổ review, không phải hành vi khách hàng.

Chia sản phẩm thành bốn nhóm theo rating:

| Nhóm rating | Khoảng rating | Số lượng bán TB | Doanh thu TB | Tỷ lệ hoàn |
|---|---|---|---|---|
| 1 (thấp nhất) | 2,50–3,45 | 321 | 11.852 | 1,61% |
| 2 | 3,45–3,71 | 480 | 17.502 | 1,42% |
| 3 | 3,71–3,95 | 537 | 16.471 | 1,42% |
| 4 (cao nhất) | 3,96–5,00 | 294 | 9.119 | 1,32% |

Hai nhóm ở hai đầu đều bán ít hơn hai nhóm giữa. Lý do là sản phẩm bán ít thì có ít review, mà trung bình của ít review dễ rơi vào mức rất cao hoặc rất thấp. Nếu vẽ biểu đồ rating và doanh thu mà không xử lý điểm này, người xem dễ kết luận sai rằng sản phẩm rating cao bán kém.

Thêm vào đó, review trong nguồn không gắn với việc mua hàng:

- Chỉ 804 trên 6.000 review (13,4%) do khách có đơn chứa sản phẩm đó viết, và chỉ 391 review (6,5%) được viết sau khi mua.
- 1.630 review có ngày viết trước ngày tạo sản phẩm.

| Cách doanh nghiệp thường làm | Project này | Vì sao hợp với dữ liệu |
|---|---|---|
| Chỉ tính review đã xác minh mua hàng. Dùng trung bình có hiệu chỉnh (Bayesian average) hoặc đặt số review tối thiểu để sản phẩm ít review không bị xếp ở hai đầu. Sau đó so rating với tỷ lệ hoàn và tỷ lệ mua lại. | Giữ `average_rating` và `review_count` trong `mart_product_performance` như số mô tả. Không vẽ biểu đồ rating so với doanh thu. | Lọc theo review đã xác minh thì chỉ còn 391 review cho 400 sản phẩm. Trên toàn bộ review, rating không có quan hệ với doanh thu hay tỷ lệ hoàn. |

## 2. Sản phẩm hay được mua cùng (cross-sell)

Câu hỏi: có cặp sản phẩm nào xuất hiện cùng đơn nhiều hơn mức ngẫu nhiên không, để gợi ý bán kèm?

Chỉ số dùng là lift của một cặp sản phẩm A, B:

```
lift = (số đơn có cả A và B × tổng số đơn) / (số đơn có A × số đơn có B)
```

Lift bằng 1 nghĩa là A và B đi cùng nhau đúng bằng mức ngẫu nhiên. Lift lớn hơn 1 nghĩa là đi cùng nhau nhiều hơn mức ngẫu nhiên. Mỗi đơn có trung bình 2,94 sản phẩm khác nhau, 6.306 đơn chỉ có một sản phẩm. Chỉ xét các cặp xuất hiện cùng nhau trong ít nhất 20 đơn, để lift không bị quyết định bởi một hai đơn.

Một lift 1,75 chưa đủ để kết luận, vì với hàng chục nghìn cặp thì ngẫu nhiên cũng sinh ra vài cặp lift cao. Để có mốc so sánh, truy vấn tạo một bản xáo trộn của `fact_sales`: mỗi dòng đơn nhận sản phẩm của một dòng khác bất kỳ. Bản xáo trộn giữ nguyên số dòng mỗi đơn và độ phổ biến của từng sản phẩm, nhưng không còn quan hệ thật nào giữa các sản phẩm.

| Dữ liệu | Số cặp ≥ 20 đơn | Lift TB | Lift cao nhất | Số cặp lift > 1,5 | Số cặp lift < 0,67 |
|---|---|---|---|---|---|
| Thật | 436 | 1,032 | 1,75 | 7 | 5 |
| Xáo trộn | 427 | 1,017 | 1,98 | 5 | 2 |

Dữ liệu thật và dữ liệu xáo trộn cho kết quả gần như nhau. Bản xáo trộn còn có cặp lift cao hơn (1,98). Vì vậy các cặp lift cao trong dữ liệu thật không phản ánh hành vi mua kèm.

| Cách doanh nghiệp thường làm | Project này | Vì sao hợp với dữ liệu |
|---|---|---|
| Phân tích giỏ hàng (market basket) với support, confidence và lift, đặt ngưỡng support tối thiểu, kiểm tra trên dữ liệu của giai đoạn sau. Kết quả dùng cho gợi ý "thường được mua cùng" và combo khuyến mãi. | Không tạo mart hay trang Power BI cho cross-sell. | Phân bố lift trên dữ liệu thật không khác dữ liệu đã xáo trộn, nên bất kỳ danh sách cặp sản phẩm nào cũng chỉ là nhiễu. |

## 3. Ảnh hưởng của giá và giảm giá

Câu hỏi: tăng hoặc giảm giá ảnh hưởng doanh số thế nào, và giảm giá có làm khách mua nhiều hơn không?

| Chỉ số | Giá trị |
|---|---|
| Sản phẩm có bán hàng | 400 |
| Sản phẩm chỉ có một `unit_price` trong mọi đơn 2021–2025 | 400 |
| Phiên bản trong `snap_products` | 400 (mỗi sản phẩm một phiên bản, chưa có phiên bản nào bị đóng) |
| Dòng có giảm giá | 15.148 trên 100.000, giảm trung bình 10,7% |
| Số lượng TB mỗi dòng, có giảm giá | 1,636 |
| Số lượng TB mỗi dòng, không giảm giá | 1,632 |
| Đơn dùng coupon | 5.483 trên 36.000 |

Muốn đo độ co giãn của cầu theo giá thì giá phải thay đổi theo thời gian. Ở đây giá của mọi sản phẩm cố định suốt 5 năm, và `unit_price` trong đơn luôn bằng `current_price` hiện tại. Snapshot `snap_products` chỉ ghi lại thay đổi từ khi project bắt đầu chạy, nên không có lịch sử giá trước đó.

Với giảm giá, số lượng mua mỗi dòng gần như bằng nhau (1,636 và 1,632), và số lượng chỉ từ 1 đến 3. Ngay cả trên dữ liệu thật, so sánh này cũng không đủ để kết luận về tác động, vì khách dùng coupon có thể khác khách không dùng. Ở đây hai nhóm thậm chí không khác nhau.

Cột `compare_at_price` (giá gốc trước khi giảm) cũng không dùng được: 246 sản phẩm để trống, 36 sản phẩm có giá gốc thấp hơn hoặc bằng giá bán hiện tại.

| Cách doanh nghiệp thường làm | Project này | Vì sao hợp với dữ liệu |
|---|---|---|
| Đo độ co giãn theo giá từ các lần đổi giá, hoặc thử A/B giá. Đo hiệu quả khuyến mãi bằng doanh số tăng thêm so với mức nền hoặc nhóm đối chứng, không so thẳng đơn có và không có coupon. | Chỉ báo cáo tỷ trọng giảm giá trên doanh thu (trang Sales overview). Không phân tích giá và khuyến mãi. | Không có thay đổi giá nào để đo. Số lượng mua không khác nhau giữa dòng có và không có giảm giá. |

## 4. Doanh số kể từ khi ra mắt sản phẩm

Câu hỏi: sản phẩm mới mất bao lâu để đạt doanh số ổn định, sản phẩm ra mắt năm nào bán tốt hơn?

Phân tích này cần ngày ra mắt. Cột gần nhất là `product_created_at`, nhưng đơn hàng thường có trước ngày này:

| Năm tạo sản phẩm | Sản phẩm | Dòng đơn | Dòng có ngày đặt trước ngày tạo | Tỷ lệ |
|---|---|---|---|---|
| 2019 | 81 | 20.742 | 0 | 0,0% |
| 2020 | 51 | 17.239 | 0 | 0,0% |
| 2021 | 57 | 15.459 | 926 | 6,0% |
| 2022 | 59 | 13.441 | 2.758 | 20,5% |
| 2023 | 62 | 15.326 | 6.072 | 39,6% |
| 2024 | 68 | 13.861 | 8.282 | 59,8% |
| 2025 | 22 | 3.932 | 3.083 | 78,4% |

Tổng cộng 21.121 dòng (21,1%), chiếm 1,21 triệu trên 5,49 triệu doanh thu ghi nhận. 264 trên 400 sản phẩm có đơn đầu tiên trước ngày tạo, trung vị sớm hơn 405 ngày, xa nhất 1.635 ngày. Đơn hàng bắt đầu từ 2021, nên sản phẩm tạo năm 2019–2020 không bị ảnh hưởng. Sản phẩm tạo càng muộn thì tỷ lệ càng cao. Điều này cho thấy ngày tạo sản phẩm được sinh độc lập với ngày đặt hàng: sản phẩm nào cũng được bán từ đầu năm 2021, bất kể ngày tạo.

| Cách doanh nghiệp thường làm | Project này | Vì sao hợp với dữ liệu |
|---|---|---|
| Lấy ngày ra mắt từ ngày sản phẩm bắt đầu được bán (hoặc ngày đầu tiên có đơn), rồi so đường doanh số theo tháng kể từ ra mắt giữa các nhóm sản phẩm ra mắt cùng kỳ. | Không phân tích theo ngày ra mắt. Ghi nhận đây là lỗi chất lượng dữ liệu nguồn. | `created_at` không phải ngày ra mắt. Dùng ngày có đơn đầu tiên thay thế thì 394 trên 400 sản phẩm có đơn đầu tiên trong quý 1/2021, sản phẩm muộn nhất là tháng 5/2021, nên không có nhóm sản phẩm mới để so sánh. |

## Thay đổi đề xuất cho project

1. Thêm test dạng warn `warn_sales_before_product_created` để báo số dòng bán hàng có ngày đặt trước ngày tạo sản phẩm (hiện là 21.121). Dùng mức warn vì đây là đặc điểm của dữ liệu nguồn, project không sửa được.
2. Ghi bốn kết quả trên vào mục Limitations của README.
3. Trên trang "Doanh thu sản phẩm", dùng chỗ trống để thêm các phân tích có tín hiệu: doanh thu theo thời gian và tăng trưởng theo danh mục, cơ cấu doanh thu theo khoảng giá.

Chú ý: bốn kết quả trên chỉ đúng với bộ dữ liệu sinh ngẫu nhiên này. Trên dữ liệu thật, cả bốn hướng đều là phân tích sản phẩm phổ biến và thường có tín hiệu. Các truy vấn trong `analyses/` vẫn dùng lại được để kiểm tra lần đầu khi đổi sang nguồn dữ liệu khác.
