#!/usr/bin/env python

import boto3
import os
import sys
import zipfile

ACCESS_KEY=
SECRET_KEY=
APP_NAME=
EXEC_JAR=
S3_BUCKET=
BUNDLE=

s3_resource = boto3.resource('s3')
s3_client = boto3.client('s3')
bucket = s3_resource.Bucket(S3_BUCKET)

# Download appspec yaml for AWS CodeDeploy
bucket.download_file('appspec.yml', 'appspec.yml')

# Download executable JAR
bucket.download_file(EXEC_JAR, EXEC_JAR)

# Download scripts to run at deploy time
scripts = s3_client.list_objects(Bucket=S3_BUCKET, Prefix='scripts')['Contents']
for s3_key in scripts:
    s3_object = s3_key['Key']
    if not s3_object.endswith('/'):
        bucket.download_file(s3_object, s3_object)
    else:
        if not os.path.exists(s3_object):
            os.makedirs(s3_object)

# Compress the downloaded files with Zip
zf = zipfile.ZipFile(BUNDLE, 'w')
zf.write('appspec.yml')
zf.write(EXEC_JAR)
for (root_dir, dir_name, file_names) in os.walk('scripts'):
    for file_name in file_names:
        file_path = os.path.join(root_dir, file_name)
        zf.write(file_path)
zf.close()

if os.path.exists(BUNDLE):
    bucket.upload_file(BUNDLE, BUNDLE)
else:
    sys.exist(1)

obj_meta = s3_client.head_object(Bucket=S3_BUCKET, Key=BUNDLE)
etag = obj_meta.get('ETag')
version_id = obj_meta.get('VersionId')

codedeploy_client = boto3.client('codedeploy')

codedeploy_client.register_application_revision(applicationName=APP_NAME,
        revision={'revisionType':'S3', 's3Location':{'bucket':S3_BUCKET, 'key':BUNDLE, 'bundleType':'zip', 'version':version_id, 'eTag':etag}}
        )
