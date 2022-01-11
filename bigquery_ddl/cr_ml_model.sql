CREATE OR REPLACE MODEL `retail.arima_plus_model`
OPTIONS(
 MODEL_TYPE='ARIMA_PLUS',
 TIME_SERIES_TIMESTAMP_COL='hourly_timestamp',
 TIME_SERIES_DATA_COL='total_sold',
 TIME_SERIES_ID_COL='product_name'
) AS
SELECT
   hourly_timestamp,
   product_name,
   total_sold
FROM
 `retail.training_data`
;
