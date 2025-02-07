# Data Engineering with SnowFlake on AWS
architectect and build ETL pipeline using snowflake on AWS

A data pipeline in Snowflake and AWS is a set of tasks that automate the movement and transformation of data between systems. This project will be a series of different ways to Architect and build ETL pipelines on Snoflake.

## Serie 1: How to automate SnowPipe To Load Data From AWS S3 To Snowflake

In this first serie, we will be learning how to automate data ingestion from S3 to SnowFlake using SnowPipe. Snowpipe is a Snowflake’s ingestion service that allows you to load your data continuously and  automatically into Snowflake. Automation here is based on event notifications. When a file is loaded into S3 and event notification is triggered to an SQS queue, the cloud storage notifies Snowpipe at the arrival of new data files to load. Snowpipe copies files into a queue, from which the data is loaded into the target table continuously.

![image](https://raw.githubusercontent.com/tmbothe/SnowFlake-Architect-and-build-data-pipeline-on-AWS/main/images/snow_aws.png)

## Data description
There are two sources of dataset, the **Song Dataset** and the **Log Dataset** .  Both dataset are currently stored in amazon S3. These files will be read from Apache Airflow and stored in some staging tables. Then another process will extract the data from staging tables and load in final tables in AWS redshift datawarehouse.
 
 ## Project Structure
 ```
 The project has two main files, here is the description:
   Data-Pipelines-with-Airflow
    |
    |   dags
    |      | sql_statements.py
    |      | udac_airflow_dag.py
    |      | images 
    |   plugins
    |      | helpers
    |          sql_queries.py
    |   operators
    |      | data_quality.py
    |      | load_dimension.py
    |      | load_fact.py
    |      | stage_redshift.py
 ``` 

   1 - `sql_statements.py` : Under the dag folder, the sql_statements has scripts to create staging and datawarehouse tables.<br>
   2 - `udac_airflow_dag`  : the udac_airflow_dag file contains all airflow task and DAG definition.<br>
 
   **The  plugins folder has two subfolder: the helpers folders that contains the helpers files, and the operators folder that has all customs operators define for the project. <br>**
   3 - `sql_queries.py`    : This file has all select statements to populate all facts and dimension tables.<br>
   4 - `data_quality.py`   : This file defines all customs logic that will help checking the data quality once the ETL is complete.<br>
   5 - `load_dimension.py` : File to load dimension tables.<br>
   6 - `load_fact.py`      : File to load fact table.<br>
   7 -  `stage_redshift.py`:  File to load staging tables.<br>
 
## Installation 

- Install [python 3.8](https://www.python.org)
- Install [Apache Airflow](https://airflow.apache.org/docs/apache-airflow/stable/installation.html)
- Clone the current repository. 
- Create IAM user in AWS and get the user access key and secret key.
- Launch and AWS redshift cluster and get the endpoint url as well as database connection information (Database name, port number , username and password).
- Follow the instruction below to configure Redshift as well as AWS credentials connections.
 ![image](https://raw.githubusercontent.com/tmbothe/Data-Pipelines-with-Airflow/main/dags/images/connections1.PNG)
 ![image](https://raw.githubusercontent.com/tmbothe/Data-Pipelines-with-Airflow/main/dags/images/connections2.PNG)
 ![image](https://raw.githubusercontent.com/tmbothe/Data-Pipelines-with-Airflow/main/dags/images/connections3.PNG)


 ## Final DAG

![image](https://raw.githubusercontent.com/tmbothe/Data-Pipelines-with-Airflow/main/dags/images/final_DAG.PNG)
