#!/bin/bash -x

APP_NAME=
BUNDLE=
DEPLOY_GROUP=
EXEC_JAR=
REGION=
S3_BUCKET=

# Given no parameter, new version will be deployed.
if [ -z "$DEPLOYMENT_ID" ]; then

	# Download appspec yaml for AWS CodeDeploy.
	aws s3 cp --region $REGION s3://$S3_BUCKET/appspec.yml . --no-progress

	# Download executable JAR.
	aws s3 cp --region $REGION s3://$S3_BUCKET/$EXEC_JAR . --no-progress

	# Download scripts to run at deploy time.
	aws s3 sync --region $REGION s3://$S3_BUCKET/scripts scripts --no-progress

	# Bundle and upload to S3 an application revision, which is a zip archive file
	# that contains deployable content and an accompanying Application Specification file.
	# A message is returned that describes how to call the create-deployment command
	# to deploy the application revision from S3 to target EC2 instances.
	# BUNDLE_INFO saves --s3-location parameter from the message.
	BUNDLE_INFO=$(aws deploy push --application-name $APP_NAME \
			--region $REGION --s3-location s3://$S3_BUCKET/$BUNDLE \
			--ignore-hidden-files --source . \
			| awk '{for(i=1;i<=NF;i++) if($i=="--s3-location") print $(i+1)}')

	if [ -z "$BUNDLE_INFO" ]; then
		echo "--s3-location is not valid."
		exit 1
	fi

	# Deploy an application revision through the specified deployment group.
	aws deploy create-deployment \
			--region $REGION --application-name $APP_NAME \
			--deployment-group-name $DEPLOY_GROUP \
			--s3-location $BUNDLE_INFO
	echo "# Use the deploymentId when you need to perform a rollback operation."

# Rollback will be done with the given parameter.
else
	echo "Deployment ID for a rollback : $DEPLOYMENT_ID"

	# Get deployment information
	DEPLOYMENT=$(aws deploy get-deployment --region $REGION --deployment-id $DEPLOYMENT_ID)

	if [ 0 -ne $? ]; then
		exit 1
	fi
	# Filter eTag and versionId
	E_TAG=$(echo $DEPLOYMENT | jq '.deploymentInfo.revision.s3Location.eTag')
	VERSION_ID=$(echo $DEPLOYMENT | jq '.deploymentInfo.revision.s3Location.version')

	if [ -z "$E_TAG" -o -z "$VERSION_ID" ]; then
		exit 1
	fi

	# Deploy an application revision through the specified deployment group.
	aws deploy create-deployment \
			--region $REGION --application-name $APP_NAME \
			--deployment-group-name $DEPLOY_GROUP \
			--s3-location bundleType=zip,eTag=$E_TAG,bucket=$S3_BUCKET,version=$VERSION_ID,key=$BUNDLE
fi