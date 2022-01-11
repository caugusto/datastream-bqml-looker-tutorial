load data 
infile '../sample_data/oracle_data.csv' "str '\n'"
append
into table FASTFRESH.ORDERS
fields terminated by ','
OPTIONALLY ENCLOSED BY '"' AND '"'
trailing nullcols
           ( TIME_OF_SALE timestamp with time zone 'YYYY-MM-DD HH24:MI:SS TZR',
             ORDER_ID,
             PRODUCT_NAME CHAR(128),
             PRICE,
             QUANTITY,
             PAYMENT_METHOD CHAR(26),
             STORE_ID,
             USER_ID
           )