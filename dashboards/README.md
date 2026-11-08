# Dashboards

| File | What it is |
|---|---|
| `cyclistic_dashboard.png` / `cyclistic.pdf` | Export of the interactive **Power BI** report |
| `cyclistic_results_summary.png` | Static summary chart set drawn in Python from the validated SQL Server results (no Power BI needed to view) |
| `cyclistic_theme.json` | Power BI theme (colours used in the summary image) |
| `powerbi_measures.dax` | DAX measures with the expected values for 2024, for checking the report |

## Rebuild the Power BI report

1. **Get Data → SQL Server**, server and database `Cyclistic_Bike`, import the table `Cyclistic_Summary_PowerBI` (produced by `sql_queries/Cyclistic_Data_Preparation.sql`).
2. **View → Themes → Browse for themes** and load `cyclistic_theme.json`.
3. In the data model, select `trip_day_name` and set **Sort by column → `trip_day_of_week`** so days appear Monday to Sunday (the pipeline uses `DATEFIRST 1`).
4. **Home → New measure**: paste the measures from `powerbi_measures.dax`.
5. Build the page (suggested layout):
   - **Top row, 5 cards:** `Total Trips` · `Member Share %` / `Casual Share %` · `Member Avg Ride (min)` vs `Casual Avg Ride (min)` · `Casual Weekday Rush %` · `E-Scooter Share %`.
   - **Line chart:** `trip_hour` on X, `Total Trips` on Y, legend `member_casual`.
   - **Clustered column:** `trip_day_name` on X, `Total Trips` on Y, legend `member_casual`.
   - **Bar:** `rideable_type` with `Total Trips`.
   - **Donut:** `member_casual` with `Total Trips`.
   - **Filled column (month):** `trip_month` with `Total Trips`, legend `member_casual`.
   - **Slicers:** `member_casual`, `rideable_type`.
6. Check the cards against the expected values at the bottom of `powerbi_measures.dax`.

## Fixes versus the first version of the dashboard
- Average ride length uses a trip-weighted measure (15.73 min), not an average of pre-aggregated rows (15.62).
- Day axis shows names sorted Monday to Sunday, not numbers.
- The `trip_hour by rideable_type` donut is removed: it summed hour numbers and carried no meaning.
- Cards show full figures (5.72M) instead of rounding to "6 triệu".
