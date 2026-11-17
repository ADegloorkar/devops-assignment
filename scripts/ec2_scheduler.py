import os
import boto3
from datetime import datetime, timezone

ec2 = boto3.client("ec2")

ACTION = os.environ["ACTION"].lower()


def lambda_handler(event, context):
    if ACTION not in ["start", "stop"]:
        raise ValueError("ACTION must be start or stop")

    target_state = "stopped" if ACTION == "start" else "running"
    desired_state = "running" if ACTION == "start" else "stopped"

    response = ec2.describe_instances(
        Filters=[
            {"Name": "tag:Environment", "Values": ["NonProd"]},
            {"Name": "tag:Autostop", "Values": ["true"]},
            {"Name": "instance-state-name", "Values": [target_state]}
        ]
    )

    for reservation in response["Reservations"]:
        for instance in reservation["Instances"]:
            instance_id = instance["InstanceId"]

            try:
                if ACTION == "start":
                    ec2.start_instances(InstanceIds=[instance_id])
                else:
                    ec2.stop_instances(InstanceIds=[instance_id])

                print(
                    f"{datetime.now(timezone.utc).isoformat()} "
                    f"SUCCESS: {ACTION} requested for {instance_id}"
                )

            except Exception as error:
                print(
                    f"{datetime.now(timezone.utc).isoformat()} "
                    f"FAILED: {ACTION} for {instance_id}: {error}"
                )

    print(f"Completed {ACTION} operation.")
