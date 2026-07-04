# 🚲 Cyclistic Bike-Share: Phân tích hành vi khách hàng để tăng tỷ lệ chuyển đổi sang Member

**Vai trò:** Data Analyst
**Công cụ:** SQL Server (T-SQL) · Power BI
**Bộ dữ liệu:** 12 tháng dữ liệu chuyến đi năm 2024 (public dataset, mô phỏng công ty xe đạp chia sẻ Cyclistic – Chicago)

---

## 1. Bối cảnh & Vấn đề kinh doanh (Ask)

Cyclistic vận hành dịch vụ chia sẻ xe đạp với hai nhóm khách hàng:

- **Member**: mua gói thành viên theo năm, giá ổn định, biên lợi nhuận cao và bền vững.
- **Casual**: mua vé lượt/vé ngày, giá cao hơn trên mỗi phút sử dụng nhưng không tạo doanh thu định kỳ.

**Vấn đề đội Marketing đang gặp:** đội ngũ tài chính của Cyclistic đã kết luận rằng khách **Member có giá trị vòng đời (LTV) cao hơn đáng kể** so với khách Casual. Tuy nhiên, ngân sách marketing hiện tại đang được phân bổ dàn trải, không nhắm đúng vào nhóm khách Casual có khả năng chuyển đổi cao nhất.

**Câu hỏi kinh doanh (business task):**
> Khách hàng Member và Casual sử dụng xe đạp khác nhau như thế nào, và Marketing nên thiết kế chiến dịch nhắm mục tiêu vào đâu (thời điểm, địa điểm, loại xe) để chuyển đổi Casual thành Member với chi phí hiệu quả nhất?

---

## 2. Mục tiêu phân tích

1. Định lượng sự khác biệt trong **hành vi sử dụng** (thời gian trong ngày, ngày trong tuần, tháng trong năm, loại xe) giữa hai nhóm khách.
2. Xác định **cửa sổ thời gian và bối cảnh sử dụng** mà khách Casual gần giống hành vi "đi làm" nhất của Member — đây là nhóm dễ chuyển đổi nhất vì đã có nhu cầu sử dụng lặp lại.
3. Đưa ra khuyến nghị chiến dịch cụ thể (thời điểm, kênh, thông điệp) thay vì khuyến nghị chung chung "tăng ưu đãi cho Casual".

---

## 3. Giả thuyết ban đầu (Hypothesis)

Trước khi phân tích, tôi đặt ra 3 giả thuyết dựa trên hiểu biết chung về hành vi đi lại đô thị:

| # | Giả thuyết | Vì sao đặt ra |
|---|---|---|
| H1 | Member sử dụng xe theo mô hình **đi làm** (2 đỉnh cao điểm sáng ~7-9h và chiều ~16-18h, tập trung ngày thường) | Người có gói thành viên năm thường dùng cho nhu cầu lặp lại, có kế hoạch |
| H2 | Casual sử dụng xe theo mô hình **giải trí** (tập trung cuối tuần, buổi trưa/chiều, thời lượng chuyến dài hơn) | Vé lượt phù hợp với nhu cầu không thường xuyên, không bị áp lực chi phí theo phút như đi làm |
| H3 | Có một nhóm nhỏ Casual đi vào khung giờ cao điểm ngày thường — đây là "Casual tiềm năng chuyển đổi" vì hành vi của họ đã giống Member | Đây là nhóm khách "gần chuyển đổi nhất", chi phí marketing để thuyết phục họ thấp hơn nhóm Casual thuần giải trí |

---

## 4. Quá trình xử lý & kiểm chứng bằng dữ liệu (Prepare → Process → Analyze)

### 4.1. Prepare — Chuẩn bị dữ liệu
- Nguồn: 12 file dữ liệu chuyến đi theo tháng (định dạng chuẩn của Divvy/Cyclistic), tổng hợp trong SQL Server.
- Đánh giá độ tin cậy: dữ liệu do bên cung cấp hệ thống ghi nhận trực tiếp (không qua khảo sát) → độ tin cậy cao, nhưng cần làm sạch vì có bản ghi lỗi hệ thống (trạm bảo trì, GPS lỗi).

### 4.2. Process — Làm sạch & biến đổi dữ liệu
Toàn bộ pipeline nằm trong [`sql_queries/Cyclistic_Data_Preparation.sql`](./sql_queries/Cyclistic_Data_Preparation.sql), gồm 4 bước:

1. **Gộp dữ liệu**: UNION ALL 12 bảng tháng thành `all_trips_2024_raw`.
2. **Làm sạch**:
   - Loại bản ghi trùng `ride_id` (dùng `ROW_NUMBER()` để giữ bản ghi có đủ tên trạm).
   - Loại chuyến có `started_at >= ended_at` (lỗi đồng bộ thời gian).
   - Loại chuyến **dưới 60 giây** — đây thường là thao tác test/lỗi khóa xe của nhân viên bảo trì, không phải chuyến đi thật, nếu giữ lại sẽ làm lệch chỉ số thời lượng trung bình.
   - Loại bản ghi thiếu tọa độ kết thúc (`end_lat`/`end_lng` NULL) — không dùng được cho phân tích trạm.
3. **Làm giàu dữ liệu**: tính `ride_length_minutes`, tách `trip_month`, `trip_day_of_week`, `trip_hour` để phục vụ phân tích theo thời gian.
4. **Tổng hợp**: GROUP BY theo `member_casual`, `rideable_type`, `trip_month`, `trip_day_of_week`, `trip_hour` → xuất bảng `Cyclistic_Summary_PowerBI` — giảm hàng triệu dòng chi tiết xuống bảng tổng hợp gọn, tăng tốc độ tải Power BI.

**Vì sao xử lý theo hướng này:** thay vì import thẳng dữ liệu thô vào Power BI (nặng, chậm, dễ sai do dữ liệu bẩn), tôi đẩy toàn bộ phần làm sạch và tổng hợp xuống tầng SQL — đúng nguyên tắc "xử lý càng gần nguồn càng tốt", giúp dashboard chỉ tập trung vào trực quan hoá.

### 4.3. Analyze — Kết quả kiểm chứng giả thuyết

![Cyclistic Dashboard](./dashboards/cyclistic_dashboard.png)

| Chỉ số | Kết quả thực tế | Đối chiếu giả thuyết |
|---|---|---|
| Tổng số chuyến đi | ~6 triệu chuyến/năm | — |
| Tỷ trọng Member / Casual | **63.6% / 36.4%** | Member chiếm đa số nhưng Casual vẫn là ~2.2 triệu chuyến — quy mô đủ lớn để đầu tư chiến dịch |
| Thời lượng chuyến trung bình | 15.62 phút (toàn bộ) | Cần xem thêm trong dashboard: Casual có xu hướng đi chuyến dài hơn Member — phù hợp mục đích giải trí thay vì di chuyển điểm-điểm |
| Phân bố theo giờ (`trip_hour`) | Member có **2 đỉnh rõ rệt** (~8h và ~17h, hình chữ M); Casual có 1 đỉnh lệch về giữa/chiều | ✅ Xác nhận **H1 và H2**: Member = mô hình đi làm, Casual = mô hình linh hoạt/giải trí |
| Phân bố theo ngày trong tuần | Casual tăng mạnh vào cuối tuần (T7-CN); Member ổn định các ngày trong tuần, giảm nhẹ cuối tuần | ✅ Củng cố thêm H2 |
| Phân bố theo tháng | Cả hai nhóm đều tăng vào các tháng nóng (giữa năm) và giảm mạnh mùa đông | Yếu tố thời tiết ảnh hưởng đến cả 2 nhóm, không phải yếu tố phân biệt hành vi |
| Loại xe sử dụng | classic_bike, electric_bike, electric_scooter phân bổ khá đồng đều (~29-35% mỗi loại) | Loại xe không phải yếu tố phân biệt mạnh giữa 2 nhóm khách trong dữ liệu này |

**Về H3** (nhóm Casual đi giờ cao điểm ngày thường): dữ liệu tổng hợp hiện tại (group theo `trip_hour` + `member_casual`) cho thấy vẫn có một tỷ lệ chuyến Casual rơi vào khung 7-9h và 16-18h các ngày thường, dù thấp hơn nhiều so với cuối tuần. Đây chính là phân khúc mục tiêu cho khuyến nghị bên dưới.

> **Giới hạn cần nêu rõ (thể hiện tư duy phân tích chín chắn):** vì bảng tổng hợp không giữ lại `ride_id` hoặc thông tin trạm ở cấp chi tiết, tôi chưa thể định lượng chính xác *bao nhiêu %* Casual đi giờ cao điểm ngày thường lặp lại nhiều lần (dấu hiệu "đi làm bằng Casual"). Đây là hướng phân tích tiếp theo tôi đề xuất ở phần Act.

---

## 5. Đề xuất hành động (Share & Act)

| Đề xuất | Cơ sở dữ liệu | Cách đo lường thành công |
|---|---|---|
| **1. Chiến dịch "Chuyển đổi giờ cao điểm"**: gửi ưu đãi nâng cấp Member cho các tài khoản Casual có ≥3 chuyến trong khung 7-9h/16-18h ngày thường trong 30 ngày | Nhóm này hành vi giống Member nhất → chi phí thuyết phục thấp, tỷ lệ chuyển đổi kỳ vọng cao hơn quảng cáo đại trà | Theo dõi tỷ lệ chuyển đổi nhóm được target vs. nhóm đối chứng (A/B test) trong 60 ngày |
| **2. Gói "Weekend Membership" hoặc combo tuần**: vì phần lớn Casual dùng xe cuối tuần, một gói thành viên linh hoạt (giá thấp hơn Member năm nhưng cao hơn vé lượt) có thể là bước đệm chuyển đổi | Dữ liệu cho thấy nhu cầu cuối tuần của Casual rất ổn định, không phải ngẫu nhiên | So sánh doanh thu/khách trước và sau khi ra gói mới |
| **3. Ưu đãi tại trạm gần khu văn phòng vào giờ cao điểm** (đề xuất gốc, được giữ lại vì có cơ sở từ H1/H3) | Trùng khớp với khung giờ Member hoạt động mạnh nhất | Theo dõi số lượt quét mã ưu đãi và tỷ lệ đăng ký Member mới tại các trạm này |
| **4. Không ưu tiên phân biệt theo loại xe** trong chiến dịch, vì dữ liệu cho thấy đây không phải yếu tố phân biệt hành vi | Phân bổ 3 loại xe gần như đồng đều ở cả 2 nhóm | — |

**Bước tiếp theo nếu có thêm dữ liệu:** truy vấn ở cấp độ `ride_id` (chưa tổng hợp) để tính tần suất lặp lại theo từng khách Casual ẩn danh — từ đó xây mô hình phân loại "Casual có khả năng chuyển đổi cao" thay vì chỉ dừng ở phân tích mô tả (descriptive) như hiện tại.

---

## 📁 Cấu trúc project
```
├── sql_queries/
│   └── Cyclistic_Data_Preparation.sql   # Pipeline gộp - làm sạch - tổng hợp dữ liệu
├── dashboards/
│   ├── cyclistic.pdf                     # Dashboard Power BI gốc
│   └── cyclistic_dashboard.png           # Ảnh xuất để nhúng trong README
└── README.md
```
