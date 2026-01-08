#!/usr/bin/env python3
"""
API Key Rotation Lambda Function

This function handles automatic rotation of API Gateway API keys for the Encryption API.
It implements a blue-green deployment strategy:
1. Enable secondary key
2. Wait for clients to switch
3. Disable primary key
4. Generate new primary key
5. Update secrets
"""

import json
import os
import boto3
from datetime import datetime, timedelta
from typing import Dict, Any

# Initialize AWS clients
apigateway = boto3.client('apigateway')
secretsmanager = boto3.client('secretsmanager')
logs = boto3.client('logs')

# Environment variables
SECRET_ARN = os.environ['SECRET_ARN']
PRIMARY_KEY_ID = os.environ['PRIMARY_KEY_ID']
SECONDARY_KEY_ID = os.environ['SECONDARY_KEY_ID']
AWS_REGION = os.environ.get('AWS_REGION_VAR', 'us-east-1')


def handler(event, context):
    """
    Main Lambda handler for API key rotation

    Args:
        event: EventBridge or manual invocation event
        context: Lambda context

    Returns:
        Response with rotation status
    """
    print(f"Starting API key rotation at {datetime.utcnow().isoformat()}")

    try:
        # Step 1: Get current secret
        current_secret = get_current_secret()
        print(f"Retrieved current secret with rotation date: {current_secret.get('rotation_date')}")

        # Step 2: Check if rotation is needed
        if not should_rotate(current_secret):
            print("Rotation not needed yet (less than 90 days since last rotation)")
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Rotation not needed',
                    'lastRotation': current_secret.get('rotation_date'),
                    'action': 'none'
                })
            }

        # Step 3: Perform rotation
        print("Starting rotation process...")

        # Enable secondary key
        enable_api_key(SECONDARY_KEY_ID)
        print(f"Enabled secondary key: {SECONDARY_KEY_ID}")

        # Wait period for clients to switch (simulate - in production, this would be a multi-phase process)
        # In real implementation, you'd trigger this in multiple stages over days

        # Disable primary key
        disable_api_key(PRIMARY_KEY_ID)
        print(f"Disabled primary key: {PRIMARY_KEY_ID}")

        # Create new primary key
        new_primary_key = create_new_api_key(f"encryption-api-primary-rotated-{datetime.now().strftime('%Y%m%d')}")
        print(f"Created new primary key: {new_primary_key['id']}")

        # Update secret with new configuration
        new_secret = {
            'primary_key': new_primary_key['value'],
            'primary_id': new_primary_key['id'],
            'secondary_key': current_secret['secondary_key'],
            'secondary_id': current_secret['secondary_id'],
            'rotation_date': datetime.utcnow().isoformat(),
            'rotated_by': 'automated-lambda',
            'old_primary_id': PRIMARY_KEY_ID
        }

        update_secret(new_secret)
        print("Updated secret with new key configuration")

        # Schedule cleanup of old primary key (keep for 7 days for rollback)
        # In production, you'd schedule another Lambda to delete this after grace period

        print("API key rotation completed successfully")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'API key rotation successful',
                'rotationDate': new_secret['rotation_date'],
                'newPrimaryKeyId': new_primary_key['id'],
                'oldPrimaryKeyId': PRIMARY_KEY_ID,
                'action': 'rotated'
            })
        }

    except Exception as e:
        print(f"ERROR: API key rotation failed: {str(e)}")

        # Attempt rollback
        try:
            rollback_rotation()
        except Exception as rollback_error:
            print(f"CRITICAL: Rollback failed: {str(rollback_error)}")

        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'API key rotation failed',
                'message': str(e),
                'action': 'failed'
            })
        }


def get_current_secret() -> Dict[str, Any]:
    """Retrieve current secret from Secrets Manager"""
    response = secretsmanager.get_secret_value(SecretId=SECRET_ARN)
    return json.loads(response['SecretString'])


def should_rotate(secret: Dict[str, Any]) -> bool:
    """
    Check if rotation is needed (90 days since last rotation)

    Args:
        secret: Current secret configuration

    Returns:
        True if rotation is needed
    """
    last_rotation = secret.get('rotation_date')
    if not last_rotation:
        return True  # No rotation date, rotate immediately

    rotation_date = datetime.fromisoformat(last_rotation.replace('Z', '+00:00'))
    days_since_rotation = (datetime.now() - rotation_date).days

    return days_since_rotation >= 90


def enable_api_key(key_id: str):
    """Enable an API Gateway API key"""
    apigateway.update_api_key(
        apiKey=key_id,
        patchOperations=[
            {
                'op': 'replace',
                'path': '/enabled',
                'value': 'true'
            }
        ]
    )


def disable_api_key(key_id: str):
    """Disable an API Gateway API key"""
    apigateway.update_api_key(
        apiKey=key_id,
        patchOperations=[
            {
                'op': 'replace',
                'path': '/enabled',
                'value': 'false'
            }
        ]
    )


def create_new_api_key(name: str) -> Dict[str, str]:
    """
    Create a new API Gateway API key

    Args:
        name: Name for the new key

    Returns:
        Dictionary with key id and value
    """
    response = apigateway.create_api_key(
        name=name,
        description=f"Rotated API key created on {datetime.utcnow().isoformat()}",
        enabled=True,
        generateDistinctId=True
    )

    return {
        'id': response['id'],
        'value': response['value']
    }


def update_secret(new_secret: Dict[str, Any]):
    """Update the secret in Secrets Manager"""
    secretsmanager.put_secret_value(
        SecretId=SECRET_ARN,
        SecretString=json.dumps(new_secret)
    )


def rollback_rotation():
    """
    Rollback rotation in case of failure
    Re-enable primary key and disable secondary
    """
    print("Attempting rollback...")
    enable_api_key(PRIMARY_KEY_ID)
    disable_api_key(SECONDARY_KEY_ID)
    print("Rollback completed")


def manual_rotation(primary_id: str, secondary_id: str):
    """
    Manual rotation trigger for testing

    Usage:
        aws lambda invoke \\
          --function-name encryption-api-key-rotation \\
          --payload '{"action": "manual_rotation"}' \\
          response.json
    """
    pass


if __name__ == "__main__":
    # For local testing
    print("API Key Rotation Lambda Function")
    print("This function runs automatically via EventBridge schedule")
