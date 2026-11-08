/* CYCLISTIC BIKE - DATA VALIDATION CHECKS
   Run AFTER Cyclistic_Data_Preparation.sql.
   Purpose: verify cleaning rules and reproduce every headline number quoted in README.md.
   NOTE: trip_day_of_week was materialized under SET DATEFIRST 1 (1 = Monday ... 7 = Sunday).
*/
USE Cyclistic_Bike;
GO

-- 1. Row counts: raw -> cleaned (how many rows each cleaning stage removed)
SELECT
    (SELECT COUNT(*) FROM all_trips_2024_raw)      AS raw_rows,
    (SELECT COUNT(*) FROM all_trips_2024_cleaned)  AS cleaned_rows,
    (SELECT COUNT(*) FROM all_trips_2024_raw)
      - (SELECT COUNT(*) FROM all_trips_2024_cleaned) AS removed_rows;

-- 2. Duplicate ride_id (expected: 0 rows)
SELECT ride_id, COUNT(*) AS cnt
FROM all_trips_2024_cleaned
GROUP BY ride_id
HAVING COUNT(*) > 1;

-- 3. Ride length range after cleaning (expected: min >= 1, max <= 1440 minutes)
SELECT MIN(ride_length_minutes) AS min_len, MAX(ride_length_minutes) AS max_len
FROM all_trips_2024_analysis;

-- 4. Invalid coordinates / categories left in cleaned data (expected: all 0)
SELECT
    SUM(CASE WHEN start_lat IS NULL OR start_lng IS NULL
              OR end_lat IS NULL OR end_lng IS NULL THEN 1 ELSE 0 END)                AS null_coords,
    SUM(CASE WHEN (start_lat = 0 AND start_lng = 0)
              OR (end_lat = 0 AND end_lng = 0) THEN 1 ELSE 0 END)                     AS zero_coords,
    SUM(CASE WHEN member_casual NOT IN ('member','casual') THEN 1 ELSE 0 END)         AS bad_member_type
FROM all_trips_2024_cleaned;

-- 5. Member vs casual: trips and share
SELECT member_casual,
       COUNT(*) AS trips,
       CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS share_pct
FROM all_trips_2024_analysis
GROUP BY member_casual;

-- 6. Average ride length, trip-weighted (do NOT average the pre-aggregated averages)
SELECT member_casual,
       CAST(SUM(avg_ride_length_mins * total_trips) / SUM(total_trips) AS DECIMAL(6,2)) AS weighted_avg_mins
FROM Cyclistic_Summary_PowerBI
GROUP BY member_casual
UNION ALL
SELECT 'overall',
       CAST(SUM(avg_ride_length_mins * total_trips) / SUM(total_trips) AS DECIMAL(6,2))
FROM Cyclistic_Summary_PowerBI;

-- 7. Hourly profile by group (H1/H2: members show 2 commute peaks, casual has one broad peak)
SELECT member_casual, trip_hour, SUM(total_trips) AS trips
FROM Cyclistic_Summary_PowerBI
GROUP BY member_casual, trip_hour
ORDER BY member_casual, trip_hour;

-- 8. Day-of-week profile by group, labelled with day names (H2)
SELECT member_casual, trip_day_of_week, trip_day_name, SUM(total_trips) AS trips
FROM Cyclistic_Summary_PowerBI
GROUP BY member_casual, trip_day_of_week, trip_day_name
ORDER BY member_casual, trip_day_of_week;

-- 9. Bike type share
SELECT rideable_type,
       SUM(total_trips) AS trips,
       CAST(100.0 * SUM(total_trips) / SUM(SUM(total_trips)) OVER () AS DECIMAL(5,2)) AS share_pct
FROM Cyclistic_Summary_PowerBI
GROUP BY rideable_type
ORDER BY trips DESC;

-- 10. H3: casual trips inside weekday commute windows (Mon-Fri, 7-9h and 16-18h)
SELECT trip_hour, SUM(total_trips) AS casual_weekday_trips
FROM Cyclistic_Summary_PowerBI
WHERE member_casual = 'casual'
  AND trip_day_of_week BETWEEN 1 AND 5
  AND trip_hour IN (7, 8, 9, 16, 17, 18)
GROUP BY trip_hour
ORDER BY trip_hour;
