# dq-oag-sftp-python

A Docker container running a data pipeline.
Tasks include:
- SFTP LIST and check against a table in RDS PostgreSQL, add if required
- SFTP GET from a remote SFTP server
- Running virus check on each file pulled from SFTP by sending them to ClamAV API
- Parse and validate XML files
- AWS S3 PUT files to S3 buckets

## Dependencies

- Docker
- Python3.7
- Drone
- AWS CLI
- AWS Keys with PUT access to S3
- AWS RDS PostgreSQL
- Kubernetes

## Structure

- **app/**
  - *Dockerfile*: describe what is installed in the container and the Python file that needs to run
  - *docker-entrypoint.sh*: bash scripts running at container startup
  - *packages.txt*: Python custom Modules
  - *ecosystem.config.js*: declare variables used by PM2 at runtime
  - **bin/**
    - *DQ_OAG_file_ingest*: Python script used with PM2 to declare imported files to PM2 at runtime
  - **scripts/**
    - *__init__.py*: declare Python module import
    - *DQ_OAG_file_ingest.py*: Python2.7 script running within the container
    - *settings.py*: declare variables passed to the *DQ_OAG_file_ingest.py* file at runtime
  - **test/**
    - *Dockerfile*: PostgreSQL sidekick container config
    - *test.py*: Test Python3.7 script
    - *start.sh*: Download, build and run Docker containers
    - *stop.sh*: Stop and remove **all** Docker containers
    - *eicar.com*: File containing a test virus string
- **kube/**
  - *deployment.yml*: describe a Kubernetes POD deployment
  - *pvc.yml*: declare a Persistent Volume in Kubernetes
  - *secret.yml*: list the Drone secrets passed to the containers during deployment  
- *.drone.yml*: CI deployment configuration
- *LICENSE*: MIT license file
- *README.md*: readme file

## Kubernetes POD connectivity

The POD consists of one Docker containers responsible for handling data.

| Container Name | Function | Language | Exposed port | Managed by |
| :--- | :---: | :---: | ---: | --- |
| dq-oag-data-ingest | Data pipeline app| Python3.7 | N/A | DQ Devops |


## RDS PostgreSQL connectivity

The RDS instance is stand alone and not part of the POD or this deployment. This **README.md** assumes the instance has been configured prior to deployment of the POD and includes:

- Database
- Table
- User
- Password

The *dq-oag-data-ingest* container connects to the PostgreSQL backend at each run using its DNS host name, username, database and password.

## Data flow

- *dq-oag-data-ingest* lists files on an SFTP server and only move to the next step of the file does not yet exist in the RDS database table
- *dq-oag-data-ingest* GET files from an external SFTP server
- sending these files to *clamav-api* with destination *dq-calamv:443*
- *OK* or *!OK* response text is sent back to *dq-oag-data-ingest*
  - *IF OK* Parse files and *IF* successful DELETE from SFTP
  - *IF !OK* file is deleted from the PVC
- Failed to parse XML files are moved to */ADT/failed_to_parse/oag*
- Upload files from the */ADT/data/oag* to S3
- Delete uploaded files from PVC

## Drone secrets

Environmental variables are set in Drone based on secrets listed in the *.drone.yml* file and they are passed to Kubernetes as required.

## Local Test suite

Testing the OAG Python script can be done by having access to AWS S3 and Docker.
The full stack comprises of 6 Docker containers within the same network linked to each other so DNS name resolution works between the components.

The containers can be started and a couple of test files generated using the *start.sh* script located in **app/test**.
The script will require the following variables passed in at runtime.

|Name|Value|Required|Description|
| --- |:---:| :---:| --- |
| pubkey | /local/path/id_rsa.pub | True | Public SSH key used by the SFTP server|
| privkey | /local/path/id_rsa | True | Private SSH used to connect to the SFTP server|
| mountpoint|  /local/path/mountpoint-dir | True | SFTP source directory|
| bucketname | s3-bucket-name | True | S3 bucket name |
| awskeyid | ABCD | True | AWS access key ID |
| awssecret | abcdb1234 | True | AWS Secret access key |
| webhook | https://hooks.slack.com/services/ABCDE12345 | True | Slack Webhook URL |

- Components:
  - SFTP container
  - OAG Python container

After the script has completed - for the first time it will take around 5 minutes to download all images - there should be a couple of test files in the Primary S3 bucket and a single *xml* file in the Secondary S3 bucket:

```
1124_YYYY_MM_DD_HH_MM_SS.xml
```
Another test file contains a test virus string and it will be located under:

```
/ADT/quarantine/oag/1124_YYYY_MM_DD_HH_MM_SS.xml
```

Also there will be a failed XML test file and it will be located under:

```
/ADT/failed_to_parse/oag//1124_YYYY_MM_DD_HH_MM_SS.xml
```

- Launching the test suite

NOTE: navigate to **app/test** first.

```
sh start.sh
```

- When done with testing stop the test suite

NOTE: **all** running containers will be stopped

```
sh stop.sh
```

## Test using Mock FTP EC2

 in order to test ingesting files in Notprod environemt prior to Prod Deployment. Below are the steps requried:

 - deploy the modified version of *dq-oag-data-ingest* pod to NOTPROD_DATABASE_URL

 - logon to the mock FTP server  via ssh as follows (the EC2 instance *mock-ftp-server-centos* in DQ notprod AWS can sometimes be stopped - so ensure it is running):

 ```
 ssh -i ~/.ssh/test_instance_nonprod.cer centos@35.177.100.82
 ```

 - Once logged on change to the *mock_ftp_user* user and change to the *oag-land* directory. Once in the *oag-land* dir, create a test file. use one of the exiting files as an example.

 - Once the test file is created, monitor the logs of the *dq-oag-data-ingest* pod to check if the test file is ingested, virus scanned, parsed and then pushed to S3 successfully by running the following command:

 ```     
 kubectl --context=acp-notprod_DQ --namespace=dq-apps-notprod logs -f dq-oag-data-ingest-<####>  -c dq-oag-data-ingest
 ```
