-- BRONZE: raw data
CREATE OR REFRESH STREAMING TABLE bronze_hotel_bookings AS
SELECT *,
       _metadata.file_name AS source_file,
       current_timestamp() AS loaded_at
FROM STREAM read_files('/Volumes/hospitality_catalog/bookings/raw_files/',
                       format => 'csv', header => true);

-- SILVER: clean data
CREATE OR REFRESH MATERIALIZED VIEW silver_bookings_clean (
  CONSTRAINT valid_stay_dates EXPECT (check_out_date > check_in_date) ON VIOLATION DROP ROW,
  CONSTRAINT valid_room_rate  EXPECT (room_rate >= 0) ON VIOLATION DROP ROW
) AS
SELECT DISTINCT
  booking_id,
  guest_id,
  booking_date,
  check_in_date,
  check_out_date,
  COALESCE(nights, DATEDIFF(check_out_date, check_in_date)) AS nights,
  INITCAP(TRIM(hotel_name))                                 AS hotel_name,
  COALESCE(INITCAP(TRIM(city)), 'Unknown')                  AS city,
  INITCAP(TRIM(region))                                     AS region,
  INITCAP(TRIM(room_type))                                  AS room_type,
  COALESCE(INITCAP(TRIM(booking_channel)), 'Unknown')       AS booking_channel,
  guests,
  room_rate,
  COALESCE(total_amount,
           DATEDIFF(check_out_date, check_in_date) * room_rate) AS total_amount,
  COALESCE(discount_amount, 0)                              AS discount_amount,
  INITCAP(TRIM(meal_plan))                                  AS meal_plan,
  TRIM(payment_method)                                      AS payment_method,
  INITCAP(TRIM(payment_status))                             AS payment_status,
  INITCAP(TRIM(booking_status))                             AS booking_status,
  guest_rating
FROM bronze_hotel_bookings;

-- SILVER: rejected rows with a reason
CREATE OR REFRESH MATERIALIZED VIEW silver_bookings_rejected AS
SELECT *,
  CASE WHEN check_out_date <= check_in_date THEN 'Check-out is not after check-in'
       ELSE 'Room rate is negative' END AS reject_reason
FROM bronze_hotel_bookings
WHERE check_out_date <= check_in_date OR room_rate < 0;

-- GOLD: monthly summary
CREATE OR REFRESH MATERIALIZED VIEW gold_monthly_bookings AS
SELECT DATE_TRUNC('MONTH', check_in_date) AS stay_month,
       COUNT(*) AS bookings,
       SUM(CASE WHEN booking_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_bookings,
       SUM(CASE WHEN booking_status = 'Completed' THEN nights ELSE 0 END) AS room_nights,
       SUM(CASE WHEN booking_status = 'Completed'
                THEN total_amount - discount_amount ELSE 0 END) AS net_revenue
FROM silver_bookings_clean
GROUP BY DATE_TRUNC('MONTH', check_in_date);

-- GOLD: hotel summary
CREATE OR REFRESH MATERIALIZED VIEW gold_hotel_summary AS
SELECT region, city, hotel_name,
       COUNT(*) AS bookings,
       SUM(CASE WHEN booking_status = 'Completed' THEN nights ELSE 0 END) AS room_nights,
       SUM(CASE WHEN booking_status = 'Completed'
                THEN total_amount - discount_amount ELSE 0 END) AS net_revenue,
       SUM(CASE WHEN booking_status = 'Completed'
                THEN total_amount - discount_amount ELSE 0 END)
         / NULLIF(SUM(CASE WHEN booking_status = 'Completed' THEN nights ELSE 0 END), 0)
         AS avg_daily_rate
FROM silver_bookings_clean
GROUP BY region, city, hotel_name;

-- GOLD: room type summary
CREATE OR REFRESH MATERIALIZED VIEW gold_room_type_summary AS
SELECT room_type,
       COUNT(*) AS bookings,
       SUM(CASE WHEN booking_status = 'Completed' THEN nights ELSE 0 END) AS room_nights,
       SUM(CASE WHEN booking_status = 'Completed'
                THEN total_amount - discount_amount ELSE 0 END) AS net_revenue,
       AVG(guest_rating) AS avg_rating
FROM silver_bookings_clean
GROUP BY room_type;

-- GOLD: channel summary
CREATE OR REFRESH MATERIALIZED VIEW gold_channel_summary AS
SELECT booking_channel,
       COUNT(*) AS bookings,
       SUM(CASE WHEN booking_status = 'Cancelled' THEN 1 ELSE 0 END) AS cancelled_bookings,
       SUM(CASE WHEN booking_status = 'Cancelled' THEN 1 ELSE 0 END) * 100.0
         / COUNT(*) AS cancellation_rate_pct,
       SUM(CASE WHEN booking_status = 'Completed'
                THEN total_amount - discount_amount ELSE 0 END) AS net_revenue
FROM silver_bookings_clean
GROUP BY booking_channel;

-- GOLD: data quality
CREATE OR REFRESH MATERIALIZED VIEW gold_data_quality AS
SELECT COUNT(*) AS bronze_rows,
       COUNT(*) - COUNT(DISTINCT booking_id) AS duplicate_rows,
       SUM(CASE WHEN check_out_date <= check_in_date THEN 1 ELSE 0 END) AS invalid_date_rows,
       SUM(CASE WHEN room_rate < 0 THEN 1 ELSE 0 END) AS negative_rate_rows,
       SUM(CASE WHEN city IS NULL THEN 1 ELSE 0 END) AS missing_city_rows,
       SUM(CASE WHEN booking_channel IS NULL THEN 1 ELSE 0 END) AS missing_channel_rows,
       SUM(CASE WHEN total_amount IS NULL THEN 1 ELSE 0 END) AS missing_amount_rows,
       SUM(CASE WHEN nights IS NULL THEN 1 ELSE 0 END) AS missing_nights_rows,
       (SELECT COUNT(*) FROM silver_bookings_clean)    AS clean_rows,
       (SELECT COUNT(*) FROM silver_bookings_rejected) AS rejected_rows
FROM bronze_hotel_bookings;
