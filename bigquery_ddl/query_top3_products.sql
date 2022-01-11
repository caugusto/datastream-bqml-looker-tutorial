SELECT product_name, SUM(quantity) as total_sales
FROM `retail.ORDERS`
GROUP BY product_name
ORDER BY total_sales desc
LIMIT 3
;
