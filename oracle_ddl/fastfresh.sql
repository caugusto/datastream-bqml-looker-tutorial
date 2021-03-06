alter database datafile '/u01/app/oracle/oradata/XE/users.dbf' autoextend on maxsize unlimited;

CREATE USER "FASTFRESH" IDENTIFIED BY tutorial_fastfresh
      DEFAULT TABLESPACE "USERS"
      TEMPORARY TABLESPACE "TEMP";

GRANT "CONNECT" TO "FASTFRESH";
GRANT "RESOURCE" TO "FASTFRESH";
GRANT UNLIMITED TABLESPACE TO "FASTFRESH";
ALTER USER FASTFRESH DEFAULT TABLESPACE USERS;


DROP TABLE FASTFRESH.ORDERS;

CREATE TABLE FASTFRESH.ORDERS ( 
time_of_sale TIMESTAMP WITH TIME ZONE,  
order_id NUMBER(38),  
product_name VARCHAR2(128),  
price NUMBER(38, 20),  
quantity NUMBER(38),  
payment_method VARCHAR2(26),  
store_id NUMBER(38),  
user_id NUMBER(38)
)
TABLESPACE USERS
;

