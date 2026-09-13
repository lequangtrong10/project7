Project 07 — User Guide: Đọc hiểu Dashboard mart_sales_report

1. Dashboard gồm những gì

6 thành phần chính, tương ứng đủ 4 yêu cầu của đề bài:

Thành phần	Loại	Trả lời câu hỏi
Total Revenue	Số liệu (Scorecard)	Tổng doanh thu quy đổi USD toàn bộ dataset
Total Orders	Số liệu (Scorecard)	Tổng số đơn hàng distinct (đếm theo order_id, không đếm theo dòng sản phẩm)
Revenue by Currency	Bar chart	Doanh thu phân theo 41 loại tiền tệ gốc
Revenue by Country	Bản đồ	Phân bố doanh thu theo quốc gia khách hàng
Revenue over Time	Biểu đồ đường	Xu hướng doanh thu theo từng ngày (27/3 → 4/6/2020)
Top Products by Revenue	Bar chart	10 sản phẩm bán chạy nhất theo doanh thu
2. Cách đọc số liệu tiền tệ — điểm dễ nhầm nhất

Có 2 cột tiền khác nhau trong dữ liệu, đừng nhầm lẫn:

sales_amount — doanh thu theo đơn vị tiền gốc (VND, EUR, JPY... trộn lẫn nhau, cộng dồn con số này không có ý nghĩa vì đơn vị khác nhau).
sales_usd_price — doanh thu đã quy đổi về USD, dùng con số này khi cần cộng/so sánh tổng.

Dashboard mặc định hiển thị theo sales_usd_price — đây là con số đáng tin để so sánh giữa các quốc gia/sản phẩm.

3. Khi thấy "trống" hoặc "Unknown" trên dashboard

Đây không phải lỗi hiển thị — dữ liệu nguồn thực sự thiếu thông tin ở những chỗ này, và hệ thống cố tình giữ nguyên thay vì tự bịa số liệu:

Nếu tổng "Total Revenue" nhỏ hơn dự kiến khi cộng tay: khoảng 78 dòng không quy đổi được sang USD (7 loại tiền tệ hiếm — ARS, BOB, CRC, DOP, GTQ, PYG, VND — chưa tìm được tỷ giá đáng tin), số doanh thu gốc (sales_amount) của các dòng này vẫn còn, chỉ riêng phần USD bị thiếu.
Nếu thấy sản phẩm/khách hàng tên "Unknown": đây là ~35% đơn hàng thiếu thông tin định danh khách (khách vãng lai, không đăng nhập) và một phần nhỏ sản phẩm không tìm thấy trong catalog gốc — không phải lỗi tính toán, mà là giới hạn thật của dữ liệu nguồn.
4. Lưu ý khi đọc biểu đồ "Revenue over Time"

Biểu đồ này có 1 đỉnh nhọn bất thường vào khoảng đầu tháng 4 — đây là 1 đơn hàng lỗi thật trong dữ liệu gốc (số lượng mua ghi nhận là 9999, rõ ràng bất thường so với hành vi mua hàng thông thường). Dòng này được giữ nguyên, không tự động loại bỏ, để phản ánh đúng dữ liệu gốc — nếu cần phân tích xu hướng "bình thường", nên loại trừ thủ công đỉnh nhọn này khi diễn giải.

5. Phạm vi thời gian dữ liệu

Toàn bộ dataset chỉ trải dài 65 ngày (27/3 → 4/6/2020) — đây là 1 lát cắt dữ liệu cố định, không phải dữ liệu real-time/liên tục cập nhật. Không nên suy diễn xu hướng dài hạn hay theo mùa từ khoảng thời gian ngắn này.

6. Câu hỏi thường gặp

Vì sao 1 quốc gia có thể không hiện trên bản đồ dù có đơn hàng?
Có 14 đơn hàng không xác định được vị trí địa lý chính xác (do lỗi tra cứu IP hoặc dữ liệu IP không hợp lệ) — số lượng rất nhỏ (dưới 0.05% tổng), không ảnh hưởng đáng kể tới bức tranh tổng thể.

Vì sao "Top Products" chỉ hiện đúng 10 sản phẩm?
Giới hạn có chủ đích để biểu đồ dễ đọc, đã loại bỏ sản phẩm "Unknown" khỏi danh sách này để không gây hiểu lầm.