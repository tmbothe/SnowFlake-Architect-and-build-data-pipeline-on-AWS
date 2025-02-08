--Create database
CREATE DATABASE dev_database 
COMMENT = 'Critical development database';

SHOW DATABASES LIKE 'dev_database';
--selecting our database
use database dev_database;

--creating schema
CREATE SCHEMA dev
COMMENT = 'A new custom schema';

-- creating integration 
CREATE STORAGE INTEGRATION s3_sf_data
TYPE = EXTERNAL_STAGE 
STORAGE_PROVIDER = S3
ENABLED = TRUE
STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::442042510197:role/snowflake-projet-role'
STORAGE_ALLOWED_LOCATIONS = ('s3://thim-snowflake-project');

desc INTEGRATION s3_sf_data;

--create a folder in our s3 landing 

CREATE OR REPLACE TABLE LINEITEM_RAW_JSON (SRC VARIANT );

CREATE OR REPLACE STAGE S3_RESTRICTED_STAGE
  STORAGE_INTEGRATION = s3_sf_data
  URL = 's3://thim-snowflake-project/streams_dev/'
  FILE_FORMAT=JSON_LOAD_FORMAT;

  list @S3_RESTRICTED_STAGE;

CREATE OR REPLACE PIPE TX_LD_PIPE 
AUTO_INGEST = true
AS COPY INTO LINEITEM_RAW_JSON FROM @S3_RESTRICTED_STAGE
FILE_FORMAT = (TYPE = 'JSON');

SHOW PIPES LIKE 'TX%';

--list the stage
list @S3_RESTRICTED_STAGE;

select * from LINEITEM_RAW_JSON limit 10;
--Create stream 
CREATE OR REPLACE STREAM lineitem_std_stream  ON TABLE LINEITEM_RAW_JSON append_only=true;

select * from lineitem_std_stream

-- create task 
CREATE OR REPLACE TASK LINEITEM_LOAD_TSK
WAREHOUSE = compute_wh
schedule = '1 minute'
when system$stream_has_data('lineitem_std_stream')
as 
merge into lineitem as li 
using 
(
   select 
        SRC:L_ORDERKEY as L_ORDERKEY,
        SRC:L_PARTKEY as L_PARTKEY,
        SRC:L_SUPPKEY as L_SUPPKEY,
        SRC:L_LINENUMBER as L_LINENUMBER,
        SRC:L_QUANTITY as L_QUANTITY,
        SRC:L_EXTENDEDPRICE as L_EXTENDEDPRICE,
        SRC:L_DISCOUNT as L_DISCOUNT,
        SRC:L_TAX as L_TAX,
        SRC:L_RETURNFLAG as L_RETURNFLAG,
        SRC:L_LINESTATUS as L_LINESTATUS,
        SRC:L_SHIPDATE as L_SHIPDATE,
        SRC:L_COMMITDATE as L_COMMITDATE,
        SRC:L_RECEIPTDATE as L_RECEIPTDATE,
        SRC:L_SHIPINSTRUCT as L_SHIPINSTRUCT,
        SRC:L_SHIPMODE as L_SHIPMODE,
        SRC:L_COMMENT as L_COMMENT
    from 
        lineitem_std_stream
    where metadata$action='INSERT'
) as li_stg
on li.L_ORDERKEY = li_stg.L_ORDERKEY and li.L_PARTKEY = li_stg.L_PARTKEY and li.L_SUPPKEY = li_stg.L_SUPPKEY
when matched then update 
set 
    li.L_PARTKEY = li_stg.L_PARTKEY,
    li.L_SUPPKEY = li_stg.L_SUPPKEY,
    li.L_LINENUMBER = li_stg.L_LINENUMBER,
    li.L_QUANTITY = li_stg.L_QUANTITY,
    li.L_EXTENDEDPRICE = li_stg.L_EXTENDEDPRICE,
    li.L_DISCOUNT = li_stg.L_DISCOUNT,
    li.L_TAX = li_stg.L_TAX,
    li.L_RETURNFLAG = li_stg.L_RETURNFLAG,
    li.L_LINESTATUS = li_stg.L_LINESTATUS,
    li.L_SHIPDATE = li_stg.L_SHIPDATE,
    li.L_COMMITDATE = li_stg.L_COMMITDATE,
    li.L_RECEIPTDATE = li_stg.L_RECEIPTDATE,
    li.L_SHIPINSTRUCT = li_stg.L_SHIPINSTRUCT,
    li.L_SHIPMODE = li_stg.L_SHIPMODE,
    li.L_COMMENT = li_stg.L_COMMENT
when not matched then insert 
(
    L_ORDERKEY,
    L_PARTKEY,
    L_SUPPKEY,
    L_LINENUMBER,
    L_QUANTITY,
    L_EXTENDEDPRICE,
    L_DISCOUNT,
    L_TAX,
    L_RETURNFLAG,
    L_LINESTATUS,
    L_SHIPDATE,
    L_COMMITDATE,
    L_RECEIPTDATE,
    L_SHIPINSTRUCT,
    L_SHIPMODE,
    L_COMMENT
) 
values 
(
    li_stg.L_ORDERKEY,
    li_stg.L_PARTKEY,
    li_stg.L_SUPPKEY,
    li_stg.L_LINENUMBER,
    li_stg.L_QUANTITY,
    li_stg.L_EXTENDEDPRICE,
    li_stg.L_DISCOUNT,
    li_stg.L_TAX,
    li_stg.L_RETURNFLAG,
    li_stg.L_LINESTATUS,
    li_stg.L_SHIPDATE,
    li_stg.L_COMMITDATE,
    li_stg.L_RECEIPTDATE,
    li_stg.L_SHIPINSTRUCT,
    li_stg.L_SHIPMODE,
    li_stg.L_COMMENT
);

SHOW TASKS;

--activate the task
ALTER TASK LINEITEM_LOAD_TSK RESUME;


select * from lineitem limit 10; --7936 
--view history tasks

SELECT name, state,
completed_time, scheduled_time, 
error_code, error_message
FROM TABLE(information_schema.task_history())
WHERE name = 'LINEITEM_LOAD_TSK'
ORDER BY COMPLETED_TIME DESC;

--suppliers summary 

CREATE OR REPLACE TABLE SUMMARY_SUPPLIERS (
   SHIP_YEAR NUMBER,
   SUPPLIER STRING,
   TOTAL NUMBER(16,2)
);

CREATE OR REPLACE TASK refresh_summary_suppliers
WAREHOUSE = COMPUTE_WH
AS
MERGE INTO SUMMARY_SUPPLIERS AS t
USING (
    SELECT YEAR(L_SHIPDATE) SHIP_YEAR,L_SUPPKEY SUPPLIER,SUM(L_QUANTITY*L_EXTENDEDPRICE) as TOTAL
    FROM lineitem 
    GROUP BY YEAR(L_SHIPDATE),L_SUPPKEY
    ORDER BY TOTAL DESC 
  ) AS s
 ON s.SUPPLIER =t.SUPPLIER AND s.SHIP_YEAR=t.SHIP_YEAR
 WHEN MATCHED THEN
    UPDATE SET TOTAL = s.TOTAL
 WHEN NOT MATCHED THEN 
 INSERT (SHIP_YEAR,SUPPLIER,TOTAL)
 VALUES(s.SHIP_YEAR,s.SUPPLIER,s.TOTAL)
;
    
DESC TASK refresh_top_suppliers;

SHOW TASKS
ALTER TASK LINEITEM_LOAD_TSK SUSPEND;
ALTER TASK REFRESH_TOP_SUPPLIERS ADD AFTER LINEITEM_LOAD_TSK;
ALTER TASK refresh_top_suppliers RESUME;
ALTER TASK LINEITEM_LOAD_TSK RESUME;

SELECT * FROM SUMMARY_SUPPLIERS lIMIT 10;


SELECT name, state,
completed_time, scheduled_time, 
error_code, error_message
FROM TABLE(information_schema.task_history())
WHERE name = 'REFRESH_TOP_SUPPLIERS';
