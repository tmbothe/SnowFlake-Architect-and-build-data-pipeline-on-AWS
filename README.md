# Data Engineering with SnowFlake on AWS
architectect and build ETL pipeline using snowflake on AWS

A data pipeline in Snowflake and AWS is a set of tasks that automates the movement and transformation of data between both systems. This project will be a series of different ways to Architect and build ETL pipelines on Snowflake.

## Serie 1: How to automate SnowPipe To Load Data From AWS S3 To Snowflake

In this first serie, we will be learning how to automate data ingestion from S3 to SnowFlake using SnowPipe. Snowpipe is a Snowflake’s ingestion service that allows you to load your data continuously and  automatically into Snowflake. Automation here is based on event notifications. When a file is loaded into S3 an event notification is triggered to an SQS queue, the cloud storage notifies Snowpipe at the arrival of new data files to load. Snowpipe copies files into a queue, from which the data is loaded into the target table continuously.

![image](https://raw.githubusercontent.com/tmbothe/SnowFlake-Architect-and-build-data-pipeline-on-AWS/main/images/snow_aws.png)

1- Files is loaded into s3 bucket </br>
2- S3 bucket tiggers an event notification to the sqs queue </br>
3- SQS queue notifies SnowPipe </br>
4- SnowPipe loads data into Snowflake's landing table </br>
7- The CDC task pulls data from the landing table and load into the production table </br>
9- Another task aggregate the data and merge into the analytics table </br>

## Loading and extracting data into snowflake (implementing streams and Change Data Capture CDC)

This section provides a set of steps that will guide us through the various nuances of loading data into Snowflake. Techniques for loading bulk data from cloud storage (AWS S3) and provides insights into the steps required to load streaming data into Snowflake by using Snowpipe.
We are going to be running all our scripts from the Snowflake web UI. We assume that you already have an AWS account and access to Snowflake free trial.  

 #### 1- Configuring Snowflake access to S3 buckets
 - Create an S3 bucket. I have created `thim-snowflake-project`
 - Navigate to AWS IAM , click on Policies and create policy. Go directly to JSON documenttab, and use the script below. Replace the `bucket` placehoder by your own S3 bucket. Give a name to your policy and click create policy. My policy is called: `snowflake-policy`
 
 ```
   {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
              "s3:GetObject",
              "s3:GetObjectVersion",
              "s3:PutObject",
              "s3:DeleteObject",
              "s3:DeleteObjectVersion"
            ],
            "Resource": "arn:aws:s3:::<bucket>/*"
        },
        {
            "Effect": "Allow",
            "Action": "s3:ListBucket",
            "Resource": "arn:aws:s3:::<bucket>"
        }
    ]
}
 ```
 - Now click on Roles in the left pane and select Create Role. Select Another AWS account when prompted to select a type. For the Account ID parameter,   enter your account ID temporarily for example `00000000`. 
Click Next: Permissions and search for the policy that we created in the previous steps, that is, the policy called  `snowflake-policy` (or the name that you assigned). Check the checkbox against the policy and click Next. Give a name to the role. Mine is `snowflake-projet-role` .
The final screen will look like the one below. Note the ARN as highlighted as we will use it later.

![image](https://raw.githubusercontent.com/tmbothe/SnowFlake-Architect-and-build-data-pipeline-on-AWS/main/images/role_arn.png)

#### 2- Create integration between Snowflake and AWS S3 bucket

Log in to Snowflake, where we will create a cloud storage integration object as follows. Under <b>STORAGE_AWS_ROLE_ARN </b>, paste the ARN that you copied in the previous step; <b>STORAGE_ALLOWED_LOCATIONS </b> denotes the paths that you want to allow your Snowflake instance access to. Please note that your role must be <b>ACCOUNTADMIN </b>in order to create a storage integration object.

 ```
  CREATE STORAGE INTEGRATION s3_sf_data
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = S3
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN =  '<arn:aws:iam::123456789123:role/Role_For_Snowflake>'
  STORAGE_ALLOWED_LOCATIONS = ('s3://<bucket>');
 ```
 After running the statement above, we can run `DESC INTEGRATION s3_sf_data;` command to check if our integration was successful. Note down the values of STORAGE_AWS_IAM_USER_ARN and STORAGE_AWS_EXTERNAL_ID as highlighted below.

 ![image](https://raw.githubusercontent.com/tmbothe/SnowFlake-Architect-and-build-data-pipeline-on-AWS/main/images/s3_integation.png)

Now, return to the AWS console, select IAM, and click Roles from the left side menu. Select the role that we created earlier, that is, Role_For_Snowflake. Click the Trust relationships tab and click edit trust relationship. Replace the highlighted values with the one you copied from steps above.

 ![image](https://raw.githubusercontent.com/tmbothe/SnowFlake-Architect-and-build-data-pipeline-on-AWS/main/images/role_integration.png)

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
