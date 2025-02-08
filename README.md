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

#### 2- Create external stage 

Let's create an external stage that uses the storage integration object we created earlier. We will try and list the files in the stage, and if we do not get any issues, it means that the configuration is correctly set up. Please ensure that you put in your desired bucket name in the following code segment. Also, make sure that you select a database and a schema before running the following commands:

```
USE ROLE SYSADMIN;
CREATE STAGE S3_RESTRICTED_STAGE
  STORAGE_INTEGRATION = S3_INTEGRATION
  URL = 's3://<bucket>'
FILE_FORMAT= '';
```
Before creating our stage a file format for our JSON file since the data we will be loading is a JSON. But this step is optional. 
```
CREATE OR REPLACE FILE FORMAT JSON_LOAD_FORMAT TYPE = 'JSON' ;

CREATE OR REPLACE STAGE S3_RESTRICTED_STAGE
  STORAGE_INTEGRATION = s3_sf_data
  URL = 's3://thim-snowflake-project/streams_dev/'
  FILE_FORMAT=JSON_LOAD_FORMAT;
```
The we run `LIST @S3_RESTRICTED_STAGE` to list all files we currently have on our S3 bucket. Whe currently have two files there.
 ![image](https://raw.githubusercontent.com/tmbothe/SnowFlake-Architect-and-build-data-pipeline-on-AWS/main/images/s3_stage_result.png)

#### 3- Create a Snowpipe and associate to the external stage 
Let's now create a Snowpipe to enable the streaming of data. The `CREATE PIPE` . Notice that we have set AUTO_INGEST to true while creating the Snowpipe. Once we configure the events on AWS, the Snowpipe will automatically load files as they arrive in the bucket:

CREATE OR REPLACE PIPE TX_LD_PIPE 
AUTO_INGEST = true
AS COPY INTO LINEITEM_RAW_JSON FROM @S3_RESTRICTED_STAGE
FILE_FORMAT = (TYPE = 'JSON');

As we see, all files coming through Snowpipe will be loaded into our table `LINEITEM_RAW_JSON`.

It is worth noting that although the Snowpipe is created, it will not load any data unless it is triggered manually through a REST API endpoint or the cloud platform generates an event that can trigger the Snowpipe. Run the SHOW PIPES command and copy the ARN value that is shown in the <b>notification_channel</b> field (as shown in the screenshot that follows). We will use that ARN value to configure event notification in AWS:
 ![image](https://raw.githubusercontent.com/tmbothe/SnowFlake-Architect-and-build-data-pipeline-on-AWS/main/images/s3_pipe.png)

#### 3- Create SQS queue notification to trigger SnowPipe
Log in back to AWS console where we will set up an event notification for the S3 bucket so that the Snowpipe gets triggered automatically upon the creation of a new file in the bucket. Click on your S3 bucket and select the Properties tab, then within the tab, click on Events. Click Add Notification on the Events screen:

![image](https://raw.githubusercontent.com/tmbothe/SnowFlake-Architect-and-build-data-pipeline-on-AWS/main/images/s3_notification.png)
As you see on the screenshot above, add the prefix which is the landing folder we created erlier in our landing S3 bucket.
For event types, select all events.

The scroll down to add the destination. In the destination section, select SQS Queue, select enter SQS queue ARN, and paste the ARN that you copied in step 6 into the SQS queue ARN field.

![image](https://raw.githubusercontent.com/tmbothe/SnowFlake-Architect-and-build-data-pipeline-on-AWS/main/images/s3_pipe.png)

At this stage, our integration should be working.
Wait for some time, and in the Snowflake web UI, execute a SELECT  query on the table. You will see new data loaded in the table.

![image](https://raw.githubusercontent.com/tmbothe/SnowFlake-Architect-and-build-data-pipeline-on-AWS/main/images/raw_data.png)
