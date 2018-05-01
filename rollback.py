#!/usr/bin/env python

# parameter1 = deployment_id

APP_NAME =
DEPLOY_GROUP =
REGION =

import boto3
import os

deployment_id = os.getenv('deployment_id')

client = boto3.client('codedeploy', region_name=REGION)

if deployment_id is None:
    deployment_id = client.list_deployments(
            applicationName=APP_NAME,
            deploymentGroupName=DEPLOY_GROUP,
            includeOnlyStatuses=[
                'Succeeded'
            ]).get('deployments')[0]

print('deploymentId to roll back with : ' + deployment_id)

deploy_info = client.get_deployment(deploymentId=deployment_id)['deploymentInfo']

deploy_result = client.create_deployment(
        applicationName=deploy_info['applicationName'],
        deploymentGroupName=deploy_info['deploymentGroupName'],
        revision={
            'revisionType': deploy_info['revision']['revisionType'],
            's3Location': {
                'bucket': deploy_info['revision']['s3Location']['bucket'],
                'key': deploy_info['revision']['s3Location']['key'],
                'bundleType': deploy_info['revision']['s3Location']['bundleType'],
                'eTag': deploy_info['revision']['s3Location']['eTag']
            }
        }
    )

print('deploymentId : ' + deploy_result.get('deploymentId'))
