import boto3
import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    Rotation stub — logs the rotation lifecycle step.
    Replace with real secret refresh logic for your credential provider.

    Secrets Manager calls this function four times per rotation:
      createSecret  → generate a new candidate secret
      setSecret     → set the new secret on the target service
      testSecret    → verify the new secret works
      finishSecret  → promote AWSPENDING to AWSCURRENT
    """
    arn   = event["SecretId"]
    token = event["ClientRequestToken"]
    step  = event["Step"]

    client = boto3.client("secretsmanager")

    metadata = client.describe_secret(SecretId=arn)
    if "RotationEnabled" not in metadata or not metadata["RotationEnabled"]:
        raise ValueError(f"Secret {arn} is not enabled for rotation")

    versions = metadata.get("VersionIdsToStages", {})
    if token not in versions:
        raise ValueError(f"Secret version {token} has no stage for secret {arn}")

    if "AWSCURRENT" in versions[token]:
        logger.info("Version %s is already AWSCURRENT — nothing to do", token)
        return
    elif "AWSPENDING" not in versions[token]:
        raise ValueError(f"Secret version {token} is not AWSPENDING for {arn}")

    logger.info("Rotation step: %s | secret: %s | token: %s", step, arn, token)

    if step == "createSecret":
        _create_secret(client, arn, token)
    elif step == "setSecret":
        _set_secret(client, arn, token)
    elif step == "testSecret":
        _test_secret(client, arn, token)
    elif step == "finishSecret":
        _finish_secret(client, arn, token)
    else:
        raise ValueError(f"Invalid step: {step}")


def _create_secret(client, arn, token):
    """Generate a new candidate secret and store it as AWSPENDING."""
    try:
        client.get_secret_value(SecretId=arn, VersionStage="AWSPENDING")
        logger.info("AWSPENDING already exists — reusing")
        return
    except client.exceptions.ResourceNotFoundException:
        pass

    current = json.loads(
        client.get_secret_value(SecretId=arn, VersionStage="AWSCURRENT")["SecretString"]
    )
    # TODO: generate a real new password / API key here
    new_secret = {
        "db_connection_string": current["db_connection_string"] + "_rotated",
        "third_party_api_key":  current["third_party_api_key"]  + "_rotated",
    }
    client.put_secret_value(
        SecretId=arn,
        ClientRequestToken=token,
        SecretString=json.dumps(new_secret),
        VersionStages=["AWSPENDING"],
    )
    logger.info("Created AWSPENDING version %s", token)


def _set_secret(client, arn, token):
    """Apply the new secret to the target service (stub)."""
    logger.info("setSecret: update credentials on the target service here")


def _test_secret(client, arn, token):
    """Verify the new secret actually works (stub)."""
    logger.info("testSecret: verify connectivity with the new secret here")


def _finish_secret(client, arn, token):
    """Promote AWSPENDING → AWSCURRENT."""
    metadata = client.describe_secret(SecretId=arn)
    current_version = next(
        v for v, stages in metadata["VersionIdsToStages"].items()
        if "AWSCURRENT" in stages
    )
    if current_version == token:
        logger.info("Version %s is already AWSCURRENT", token)
        return
    client.update_secret_version_stage(
        SecretId=arn,
        VersionStage="AWSCURRENT",
        MoveToVersionId=token,
        RemoveFromVersionId=current_version,
    )
    logger.info("Promoted version %s to AWSCURRENT", token)