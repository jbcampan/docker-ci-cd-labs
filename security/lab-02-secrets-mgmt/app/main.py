import json
import os

import boto3
from botocore.exceptions import ClientError


def fetch_credentials():
    # Secret NAME is configuration — safe as an env var.
    # The secret VALUE is never stored anywhere outside Secrets Manager.
    secret_name = os.environ["APP_SECRET_NAME"]
    region = os.getenv("AWS_REGION", "eu-west-3")

    client = boto3.client("secretsmanager", region_name=region)

    try:
        response = client.get_secret_value(SecretId=secret_name)
    except ClientError as e:
        # Raised when the secret doesn't exist or IAM permissions are insufficient.
        # Without this, boto3 throws a cryptic traceback with no actionable message.
        raise RuntimeError(f"Could not fetch secret '{secret_name}': {e}") from e

    secret = json.loads(response["SecretString"])

    try:
        return {
            "db_connection_string": secret["db_connection_string"],
            "third_party_api_key": secret["third_party_api_key"],
        }
    except KeyError as e:
        # Raised when the JSON in Secrets Manager is missing an expected field.
        # Happens if the secret was manually edited or seeded with wrong keys.
        raise RuntimeError(f"Secret JSON is missing expected key: {e}") from e


if __name__ == "__main__":
    credentials = fetch_credentials()
    # Safety: never print actual values — only confirm the keys are present.
    print(f"Credentials loaded: {list(credentials.keys())}")