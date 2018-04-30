#!/bin/bash

APP_NAME=
BUNDLE=
DEPLOY_GROUP=
EXEC_JAR=
REGION=
S3_BUCKET=

# Download appspec yaml for AWS CodeDeploy
aws s3 cp --region $REGION s3://$S3_BUCKET/appspec.yml .

# Download executable JAR
aws s3 cp --region $REGION s3://$S3_BUCKET/$EXEC_JAR .

# Download scripts to run at deploy time
aws s3 sync --region $REGION s3://$S3_BUCKET/scripts scripts

# Bundles and uploads to S3 an application revision, which is a zip archive file
# that contains deployable content and an accompanying Application Specification file.
# A message is returned that describes how to call the create-deployment command
# to deploy the application revvision from S3 to target EC2 instances.
# BUNDLE_INFO saves --s3-location parameter from the message.
BUNDLE_INFO=$(aws deploy push --application-name $APP_NAME \
        --region $REGION --s3-location s3://$S3_BUCKET/$BUNDLE \
        --ignore-hidden-files --source . \
        |awk '{for(i=1;i<=NF;i++) if($i=="--s3-location") print $(i+1)}')

# The files used to deploy will be removed for the next deployment.
rm -r ./*

if [ -z "$BUNDLE_INFO" ]; then
    exit 1
fi

# Deploys an application revision through the specified deployment group.
aws deploy create-deployment \
        --region $REGION --application-name $APP_NAME \
        --deployment-group-name $DEPLOY_GROUP \
        --s3-location $BUNDLE_INFO
