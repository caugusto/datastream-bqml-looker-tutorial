CREATE TABLE `retail.training_data`
AS
   SELECT
       TIMESTAMP_TRUNC(time_of_sale, HOUR) as hourly_timestamp, 
product_name, 
SUM(quantity) AS total_sold
   FROM `retail.ORDERS`
       GROUP BY hourly_timestamp, product_name
       HAVING hourly_timestamp BETWEEN TIMESTAMP_TRUNC('2021-11-22', HOUR) AND TIMESTAMP_TRUNC('2021-11-28', HOUR)
       ORDER BY hourly_timestamp
;
