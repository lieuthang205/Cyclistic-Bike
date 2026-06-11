/* DỰ ÁN CYCLISTIC BIKE - DATA PREPARATION
   Quy trình: Gom dữ liệu -> Làm sạch -> Phân tích -> Tổng hợp
*/

USE Cyclistic_Bike;
GO

-- 1. GỘP DỮ LIỆU 12 THÁNG
SELECT * INTO all_trips_2024_raw
FROM (
    SELECT * FROM trips_2024_01 UNION ALL SELECT * FROM trips_2024_02
    UNION ALL SELECT * FROM trips_2024_03 UNION ALL SELECT * FROM trips_2024_04
    UNION ALL SELECT * FROM trips_2024_05 UNION ALL SELECT * FROM trips_2024_06
    UNION ALL SELECT * FROM trips_2024_07 UNION ALL SELECT * FROM trips_2024_08
    UNION ALL SELECT * FROM trips_2024_09 UNION ALL SELECT * FROM trips_2024_10
    UNION ALL SELECT * FROM trips_2024_11 UNION ALL SELECT * FROM trips_2024_12
) AS combined_data;

-- 2. LÀM SẠCH DỮ LIỆU (CLEANING)
-- Loại bỏ trùng lặp, thời gian âm, chuyến đi < 1 phút và dữ liệu tọa độ lỗi
WITH ranked_trips AS (
    SELECT *,
           ROW_NUMBER() OVER (
                PARTITION BY ride_id 
                ORDER BY (CASE WHEN start_station_name IS NOT NULL THEN 1 ELSE 2 END), started_at
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
  AND DATEDIFF(SECOND, started_at, ended_at) >= 60
  AND end_lat IS NOT NULL 
  AND end_lng IS NOT NULL;

-- 3. TẠO BẢNG PHÂN TÍCH (ANALYSIS)
-- Bổ sung các cột tính toán phục vụ Dashboard
SELECT 
    *,
    DATEDIFF(SECOND, started_at, ended_at) / 60.0 AS ride_length_minutes,
    DATEPART(MONTH, started_at) AS trip_month,
    DATEPART(WEEKDAY, started_at) AS trip_day_of_week,
    DATEPART(HOUR, started_at) AS trip_hour
INTO all_trips_2024_analysis
FROM all_trips_2024_cleaned;

-- 4. TỔNG HỢP DỮ LIỆU ĐỂ XUẤT POWER BI (AGGREGATION)
-- Nén dữ liệu để tăng hiệu năng khi import vào Dashboard
SELECT 
    member_casual,
    rideable_type,
    trip_month,
    trip_day_of_week,
    trip_hour,
    COUNT(*) AS total_trips,
    AVG(ride_length_minutes) AS avg_ride_length_mins
INTO Cyclistic_Summary_PowerBI
FROM all_trips_2024_analysis
GROUP BY member_casual, rideable_type, trip_month, trip_day_of_week, trip_hour;

-- 5. CÁC CÂU LỆNH TRUY VẤN KIỂM TRA (SAMPLES)
SELECT TOP 100 * FROM Cyclistic_Summary_PowerBI;

-- So sánh hành vi giữa Member và Casual
SELECT 
    member_casual,
    COUNT(*) AS total_trips,
    AVG(ride_length_minutes) AS avg_ride_length
FROM all_trips_2024_analysis
GROUP BY member_casual;