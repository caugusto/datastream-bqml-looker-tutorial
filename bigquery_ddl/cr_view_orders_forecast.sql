CREATE OR REPLACE VIEW `retail.orders_forecast` AS (
SELECT
timestamp,
product_name,
SUM(forecast_value) AS forecast,
SUM(actual_value) AS actual
from
(
SELECT
   TIMESTAMP_TRUNC(TIME_OF_SALE, HOUR) AS timestamp,
   product_name,
   SUM(QUANTITY) as actual_value,
   NULL AS forecast_value
   FROM   `retail.ORDERS`
   GROUP BY timestamp, product_name
UNION ALL
SELECT
       forecast_timestamp AS timestamp,
       product_name,
       NULL AS actual_value,
       forecast_value,
           FROM ML.FORECAST(MODEL `retail.arima_plus_model`,
               STRUCT(720 AS horizon))
       ORDER BY timestamp
)
GROUP BY timestamp, product_name
ORDER BY timestamp
)
;
