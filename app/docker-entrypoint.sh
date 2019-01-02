#!/bin/bash

# Copy all files and folders from the staging area to PVC
cp -R /tmp/ADT/data /ADT
cp -R /tmp/ADT/stage /ADT
cp -R /tmp/ADT/scripts /ADT
cp -R /tmp/ADT/quarantine /ADT
cp -R /tmp/ADT/log /ADT
cp -R /tmp/ADT/bin /ADT
cp /dq-ssm_ingest/ADT/sftp_oag_client_maytech.py /ADT/scripts

# Set permissions
chown -R runner:runner /ADT/data
chown -R runner:runner /ADT/stage
chown -R runner:runner /ADT/scripts
chown -R runner:runner /ADT/quarantine
chown -R runner:runner /ADT/log
chown -R runner:runner /ADT/bin

exec "$@"
