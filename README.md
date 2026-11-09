# Hotel Booking Analytics Platform

A Medallion Architecture project (Bronze, Silver, Gold) built on Databricks using Lakeflow Spark Declarative Pipelines and SQL, with an AI/BI dashboard.

## Goal
Turn a messy hotel bookings CSV (1,316 rows, 20 columns) into clean, trusted Gold tables and a 3-page dashboard.

## Architecture
CSV in Unity Catalog Volume -> Bronze -> Silver -> Gold -> Dashboard

| Layer | Tables | What it does |
|---|---|---|
| Bronze | bronze_hotel_bookings | Keeps the raw data, adds file name and load time |
| Silver | silver_bookings_clean, silver_bookings_rejected | Cleans the data, saves bad rows with a reason |
| Gold | gold_monthly_bookings, gold_hotel_summary, gold_room_type_summary, gold_channel_summary, gold_data_quality | Business summaries and data-quality checks |

## How to run
1. Create catalog `hospitality_catalog`, schema `bookings` and volume `raw_files`.
2. Upload `hotel_bookings_raw.csv` into the volume.
3. Create an ETL pipeline with default catalog `hospitality_catalog` and schema `bookings`.
4. Add `hotel_pipeline.sql` to the pipeline.
5. Click Run pipeline.
6. Build the AI/BI dashboard on the 5 Gold tables and publish it.

## Results
| Check | Value |
|---|---|
| Bronze rows | 1,316 |
| Clean rows | 1,269 |
| Rejected rows | 21 |
| Duplicates removed | 26 |
| Reconciliation (1,269 + 21 + 26 = 1,316) | Passed |
| Net revenue (Completed only) | about 15.05M |
| Room nights | 3,107 |
| Cancelled bookings | 186 |

## Dashboard pages
1. Overview: KPI cards, net revenue by month, net revenue by city
2. Hotels, Rooms and Channels: hotel revenue, average daily rate, room type, cancellation rate by channel
3. Data Quality: row counts, reconciliation, problem counts

Filters: stay month, region, room type.

## Screenshots
See the `ScreenShort` folder.

## Cleaning rules
See `cleaning_rules.md`.

## Tools
Databricks, SQL, Lakeflow Spark Declarative Pipelines, Unity Catalog, AI/BI Dashboards
