# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: MIT-0

import boto3
import json
import os

def lambda_handler(event, context):
    try:
        # Validate the event source and detail type
        if (
            event.get("source") == "aws.backup"
            and event.get("detail-type") == "Recovery Point State Change"
        ):
            # Extract necessary details from the event
            snapshot_arn = event["resources"][0]
            status = event["detail"]["status"]
            db_arn = event["detail"]["resourceArn"]
            region = event["region"]

            # Only proceed if the status is 'COMPLETED'
            if status == "COMPLETED":
                # Parse out the database identifier from the ARN
                # Extracting the DB instance identifier from the ARN
                db_identifier = f"copy-of-{db_arn.split(':')[-1]}"
                source_account = db_arn.split(":")[4]
                source_region = db_arn.split(":")[3]
                tags = [
                    {
                        "Key": "copied-from-prod",
                        "Value": "true"
                    },
                    {
                        "Key": "source-region",
                        "Value": source_region
                    },
                    {
                        "Key": "source-account",
                        "Value": source_account
                    },
                ]

                subnet_group_name = os.getenv("DB_DUBNET_GROUP_NAME")

                # Call the restore function
                response = restore_from_snapshot(db_identifier, snapshot_arn, region, subnet_group_name, tags)

                # Return status with the DB identifier
                status_code = response.get("ResponseMetadata", {}).get("HTTPStatusCode")
                if status_code == "200":
                    message = f"RDS snapshot {snapshot_arn} is being restored to {db_identifier}"
                else:
                    message = f"Failed to restore snapshot {snapshot_arn} to {db_identifier}. Please check the logs."

                return {
                    "HTTPStatusCode": status_code,
                    "DBType": "DBInstance",
                    "DBInstanceArn": response.get("DBInstance", {}).get("DBInstanceArn"),
                    "message": message
                }
            else:
                return {
                    "statusCode": 400,
                    "message": "Backup snapshot is not in a COMPLETED state.",
                }
        else:
            return {
                "statusCode": 400,
                "message": "Invalid event source or detail type.",
            }

    except Exception as e:
        print(f"Error occurred: {e}")
        return {"statusCode": 500, "body": json.dumps(f"Error: {str(e)}")}


def restore_from_snapshot(db_identifier, snapshot_arn, region_name, subnet_group_name, tags):
    try:
        rds_client = boto3.client("rds", region_name=region_name)

        print(f"Restoring database {db_identifier} from snapshot {snapshot_arn}...")

        response = rds_client.restore_db_instance_from_db_snapshot(
            DBInstanceIdentifier=db_identifier,
            DBSnapshotIdentifier=snapshot_arn,
            PubliclyAccessible=False,  # Adjust based on security needs
            DBSubnetGroupName=subnet_group_name,
            Tags = tags
        )
        return response

    except Exception as e:
        print(f"Error during database restore: {e}")
        return {"ResponseMetadata": {"HTTPStatusCode": 500}}
