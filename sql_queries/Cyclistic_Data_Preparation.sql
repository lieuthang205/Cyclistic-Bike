/* DỰ ÁN CYCLISTIC BIKE - DATA PREPARATION (ĐÃ SỬA LỖI)
   Quy trình: Gom dữ liệu -> Làm sạch -> Phân tích -> Tổng hợp
*/

USE Cyclistic_Bike;
GO

SET DATEFIRST 1;
GO

-- =====================================================================
-- 1. GỘP DỮ LIỆU 12 THÁNG
--    Liệt kê cột tường minh thay vì SELECT * để tránh lệch cột
--    giữa các bảng tháng nếu thứ tự/khai báo cột không đồng nhất.
-- =====================================================================
IF OBJECT_ID('dbo.all_trips_2024_raw', 'U') IS NOT NULL
    DROP TABLE dbo.all_trips_2024_raw;
GO

DECLARE @cols NVARCHAR(MAX) = N'
    ride_id, rideable_type, started_at, ended_at,
    start_station_name, start_station_id,
    end_station_name, end_station_id,
    start_lat, start_lng, end_lat, end_lng,
    member_casual';

DECLARE @sql NVARCHAR(MAX) = N'
SELECT ' + @cols + N' INTO all_trips_2024_raw
FROM (
    SELECT ' + @cols + N' FROM trips_2024_01
    UNION ALL SELECT ' + @cols + N' FROM trips_2024_02
    UNION ALL SELECT ' + @cols + N' FROM trips_2024_03
    UNION ALL SELECT ' + @cols + N' FROM trips_2024_04
    UNION ALL SELECT ' + @cols + N' FROM trips_2024_05
    UNION ALL SELECT ' + @cols + N' FROM trips_2024_06
    UNION ALL SELECT ' + @cols + N' FROM trips_2024_07
    UNION ALL SELECT ' + @cols + N' FROM trips_2024_08
    UNION ALL SELECT ' + @cols + N' FROM trips_2024_09
    UNION ALL SELECT ' + @cols + N' FROM trips_2024_10
    UNION ALL SELECT ' + @cols + N' FROM trips_2024_11
    UNION ALL SELECT ' + @cols + N' FROM trips_2024_12
) AS combined_data;';

EXEC sp_executesql @sql;
GO

-- =====================================================================
-- 2. LÀM SẠCH DỮ LIỆU (CLEANING)
--    - Loại bỏ trùng lặp ride_id
--    - Loại thời gian âm / chuyến < 1 phút
--    - Loại chuyến quá dài bất thường (> 24h, nghi ngờ mất xe/bảo trì)
--    - Loại tọa độ NULL hoặc (0,0) ở cả điểm đi và điểm đến
--    - Chỉ giữ member_casual hợp lệ
-- =====================================================================
IF OBJECT_ID('dbo.all_trips_2024_cleaned', 'U') IS NOT NULL
    DROP TABLE dbo.all_trips_2024_cleaned;
GO

WITH ranked_trips AS (
    SELECT *,
           ROW_NUMBER() OVER (
                PARTITION BY ride_id
                ORDER BY
                    CASE WHEN start_station_name IS NOT NULL
                          AND end_station_name IS NOT NULL
                          AND start_lat IS NOT NULL AND start_lng IS NOT NULL
                          AND end_lat IS NOT NULL AND end_lng IS NOT NULL
                         THEN 1 ELSE 2 END,
                    started_at
           ) AS row_num
    FROM all_trips_2024_raw
)
SELECT
    ride_id, rideable_type, started_at, ended_at,
    start_station_name, start_station_id,
    end_station_name, end_station_id,
    start_lat, start_lng, end_lat, end_lng,
    member_casual
INTO all_trips_2024_cleaned
FROM ranked_trips
WHERE row_num = 1
  AND started_at < ended_at
  AND DATEDIFF(SECOND, started_at, ended_at) >= 60          -- chuyến >= 1 phút
  AND DATEDIFF(SECOND, started_at, ended_at) <= 86400        -- chuyến <= 24 giờ (loại outlier)
  AND start_lat IS NOT NULL AND start_lng IS NOT NULL
  AND end_lat IS NOT NULL AND end_lng IS NOT NULL
  AND NOT (start_lat = 0 AND start_lng = 0)                  -- loại tọa độ lỗi GPS (0,0)
  AND NOT (end_lat = 0 AND end_lng = 0)
  AND member_casual IN ('member', 'casual');                 -- chỉ giữ giá trị hợp lệ
GO

-- =====================================================================
-- 3. TẠO BẢNG PHÂN TÍCH (ANALYSIS)
--    Bổ sung các cột tính toán phục vụ Dashboard
--    + trip_day_name để tránh nhầm lẫn số thứ tự ngày (phụ thuộc DATEFIRST)
-- =====================================================================
IF OBJECT_ID('dbo.all_trips_2024_analysis', 'U') IS NOT NULL
    DROP TABLE dbo.all_trips_2024_analysis;
GO

SELECT
    *,
    DATEDIFF(SECOND, started_at, ended_at) / 60.0 AS ride_length_minutes,
    DATEPART(MONTH, started_at)   AS trip_month,
    DATEPART(WEEKDAY, started_at) AS trip_day_of_week,   -- 1 = Thứ Hai (do SET DATEFIRST 1)
    DATENAME(WEEKDAY, started_at) AS trip_day_name,      -- tên ngày, tránh nhầm lẫn khi đọc
    DATEPART(HOUR, started_at)    AS trip_hour
INTO all_trips_2024_analysis
FROM all_trips_2024_cleaned;
GO

-- =====================================================================
-- 4. TỔNG HỢP DỮ LIỆU ĐỂ XUẤT POWER BI (AGGREGATION)
--    Nén dữ liệu để tăng hiệu năng khi import vào Dashboard
-- =====================================================================
IF OBJECT_ID('dbo.Cyclistic_Summary_PowerBI', 'U') IS NOT NULL
    DROP TABLE dbo.Cyclistic_Summary_PowerBI;
GO

SELECT
    member_casual,
    rideable_type,
    trip_month,
    trip_day_of_week,
    trip_day_name,
    trip_hour,
    COUNT(*) AS total_trips,
    AVG(ride_length_minutes) AS avg_ride_length_mins
INTO Cyclistic_Summary_PowerBI
FROM all_trips_2024_analysis
GROUP BY member_casual, rideable_type, trip_month, trip_day_of_week, trip_day_name, trip_hour;
GO

-- =====================================================================
-- 5. CÁC CÂU LỆNH TRUY VẤN KIỂM TRA (SAMPLES)
-- =====================================================================
SELECT TOP 100 * FROM Cyclistic_Summary_PowerBI;

-- So sánh hành vi giữa Member và Casual
SELECT
    member_casual,
    COUNT(*) AS total_trips,
    AVG(ride_length_minutes) AS avg_ride_length
FROM all_trips_2024_analysis
GROUP BY member_casual;

-- Kiểm tra nhanh: có còn bản ghi trùng ride_id không (kỳ vọng = 0 dòng)
SELECT ride_id, COUNT(*) AS cnt
FROM all_trips_2024_cleaned
GROUP BY ride_id
HAVING COUNT(*) > 1;

-- Kiểm tra nhanh: khoảng ride_length_minutes sau khi lọc (kỳ vọng trong [1, 1440])
SELECT MIN(ride_length_minutes) AS min_len, MAX(ride_length_minutes) AS max_len
FROM all_trips_2024_analysis;
